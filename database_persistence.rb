require 'pg'

class DatabasePersistence
  attr_reader :errors

  def initialize(logger)
    @logger = logger
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          elsif Sinatra::Base.test?
            PG.connect(dbname: 'flights_test')
          else
            PG.connect(dbname: 'flights')
          end
  end

  def query(statement, *params)
    @errors = []
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def create_flight(flight)
    airline_id = find_airline_id(flight[:airline])
    sql = <<~SQL
      INSERT INTO flights (date, airline_id, flight_number, origin, destination, departure_time, arrival_time, next_day_arrival, routing, travel_time, price)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
    SQL
    begin
      query(sql, flight[:date], airline_id, flight[:flight_number], flight[:origin], flight[:destination], flight[:departure_time], flight[:arrival_time], flight[:next_day_arrival], flight[:routing], flight[:travel_time], flight[:price])
    rescue PG::Error => e
      @logger.info "Flight #{flight} not added due to SQL error: #{e}"
      puts "Flight #{flight} not added due to SQL error: #{e}"
      @errors << e
    end
  end

  def find_flight(id)
    sql = "SELECT * FROM flights WHERE id = $1"
    result = query(sql, id)
    flight_object_from_tuple(result[0])
  end

  def all_flights
    result = query("SELECT * FROM flights")
    flights = result.map do |tuple|
      flight_object_from_tuple(tuple)
    end
  end

  def update_flight(id, new_flight_params)
    date = new_flight_params[:date].to_s
    airline_id = find_airline_id(new_flight_params[:airline])
    flight_number = new_flight_params[:flight_number]
    origin = new_flight_params[:origin]
    destination = new_flight_params[:destination]
    departure_time = new_flight_params[:departure_time]
    arrival_time = new_flight_params[:arrival_time]
    next_day_arrival = new_flight_params[:next_day_arrival]
    routing = new_flight_params[:routing]
    travel_time = new_flight_params[:travel_time]
    price = new_flight_params[:price]
    next_day_arrival = new_flight_params[:next_day_arrival]
    sql = <<~SQL
      UPDATE flights
      SET "date" = $1, airline_id = $2, flight_number = $3, origin = $4, destination = $5, departure_time = $6, arrival_time = $7, next_day_arrival = $8, routing = $9, travel_time = $10, price = $11
      WHERE id = $12
    SQL
    query(sql, date, airline_id, flight_number, origin, destination, departure_time, arrival_time, next_day_arrival, routing, travel_time, price, id)
  end

  def delete_flight(id)
    query("DELETE FROM flights WHERE id = $1", id)
  end

  def delete_all_flights
    query("DELETE FROM flights")
  end

  def disconnect
    @db.close
  end

  def delete_all_data
    %w[flights].each do |table_name|
      delete_all_and_reset_id_sequence(table_name)
    end
  end

  def unique_flight?(flight)
    sql = <<~SQL
      SELECT * FROM flights WHERE airline_id = (SELECT id FROM airlines WHERE name = $1) AND flight_number = $2
    SQL
    result = query(sql, flight[:airline], flight[:flight_number])
    result.ntuples == 0 || (result.ntuples == 1 && result.first['id'].to_i == flight[:id].to_i)
  end

  private

  def find_airline_id(airline_name)
    sql = "SELECT id FROM airlines WHERE name = $1"
    result = query(sql, airline_name)
    result.field_values('id')[0].to_i
  end

  def find_airline_name(airline_id)
    sql = "SELECT name FROM airlines WHERE id = $1"
    result = query(sql, airline_id)
    result.field_values('name')[0]
  end

  def flight_object_from_tuple(tuple)
    {
      id: tuple['id'].to_i,
      date: Date.parse(tuple['date']),
      airline: find_airline_name(tuple['airline_id'].to_i),
      flight_number: tuple['flight_number'],
      origin: tuple['origin'],
      destination: tuple['destination'], 
      departure_time: Time.parse(tuple['departure_time']),
      arrival_time: Time.parse(tuple['arrival_time']),
      next_day_arrival: tuple['next_day_arrival'] == 't',
      routing: tuple['routing'],
      travel_time: tuple['travel_time'].to_i,
      price: tuple['price'].to_f
    }
  end

  def delete_all_and_reset_id_sequence(table_name)
    query("DELETE FROM #{table_name}")
    query("ALTER SEQUENCE IF EXISTS #{table_name}_id_seq  RESTART WITH 1")
  end
end
