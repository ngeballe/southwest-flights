require 'sinatra'
require 'sinatra/reloader'
require 'yaml/store'

configure do
  enable :sessions
  set :session_key, 'd898w98vf8909sidfuiqwuopffdlcxksjiowqu97ncjh7282'
end

before do
  @store = YAML::Store.new data_path
  @store.transaction do
    @flights = @store[:flights] || []
  end
end

after do
  @store.transaction do
    @store[:flights] = @flights
  end
end

helpers do
  def format_date(date)
    date.strftime('%a., %b. %-d') if date
  end

  def format_arrival_time(flight)
    arrival_time_string = format_time(flight[:arrival_time])
    arrival_time_string << " next day" if flight[:next_day_arrival]
    arrival_time_string
  end

  def format_travel_time(flight)
    hours, minutes = flight[:travel_time].divmod(60)
    format('%dh %02dm', hours, minutes)
  end
end

FLIGHT_ATTRIBUTES = ['Date', 'Airline', 'Flight Number', 'Origin', 'Destination', 'Departure Time', 'Arrival Time', 'Routing', 'Travel Time', 'Price']

def data_path
  if ENV["RACK_ENV"] == "test"
    'test/data.yml'
  else
    'data.yml'
  end
end

def errors_for_flight(date, airline, number, origin, destination, departure_time, arrival_time, price)
  errors = []
  begin
    unless date.empty?
      date_object = Date.parse(date)
    end
  rescue ArgumentError
    errors << "Invalid date."
  end
  errors << "Please enter the airline name." if airline.empty?
  errors << "Please enter the airport you're departing from." if origin.empty?
  errors << "Please enter the destination airport." if destination.empty?
  errors << "Please enter the departure time." if departure_time == ''
  errors << "Please enter the arrival time" if arrival_time == ''
  errors << "Please enter the price." if price == '' || price.nil?
  errors
end

def set_flight
  @flight = @flights.detect { |flight| flight[:id] == params[:id].to_i }
end

def parse_time(time_string, next_day = false)
  if time_string.empty?
    ''
  elsif next_day
    Time.parse(time_string) + 60 * 60 * 24
  else
    Time.parse(time_string)
  end
end

def parse_date(date_string)
  if date_string.empty?
    nil
  else
    begin
      Date.parse(date_string)
    rescue ArgumentError
      nil
    end
  end
end

def format_time(time)
  time.strftime('%-I:%M %p')
end

def military_time(time)
  time.strftime('%H:%M')
end

def next_id(collection)
  max_id = collection.map { |object| object[:id] }.max || 0
  max_id + 1
end

def to_minutes(travel_time_string)
  hours, minutes = travel_time_string.split.map(&:to_i)
  hours * 60 + minutes
end

get '/' do
  redirect '/flights'
end

get '/flights' do
  case params[:sort]
  when 'price'
    @flights.sort_by! { |flight| flight[:price] }
  when 'duration'
    @flights.sort_by! { |flight| flight[:travel_time] }
  when 'takeoff'
    @flights.sort_by! { |flight| flight[:departure_time] }
  when 'landing'
    @flights.sort_by! { |flight| flight[:arrival_time] }
  end

  erb :flights
end

get '/flights/new' do
  erb :new_flight
end

post '/flights' do
  date = params[:date]
  airline = params[:airline].strip
  number = params[:number]
  origin = params[:origin].strip
  destination = params[:destination].strip
  departure_time = parse_time(params[:departure_time])
  
  next_day_arrival = (params[:next_day_arrival] == 'on')
  arrival_time = parse_time(params[:arrival_time], next_day_arrival)
  routing = params[:routing]
  travel_time = params[:travel_time]
  price = params[:price]

  @errors = errors_for_flight(date, airline, number, origin, destination, departure_time, arrival_time, price)
  if @errors.any?
    status 422
    session[:error] = erb(:flight_errors)
    erb :new_flight
  else
    flight = {
      id: next_id(@flights),
      date: parse_date(date),
      airline: airline,
      number: number,
      origin: origin,
      destination: destination,
      departure_time: departure_time,
      arrival_time: arrival_time,
      next_day_arrival: next_day_arrival,
      routing: routing,
      travel_time: to_minutes(travel_time),
      price: price[1..-1].to_i
    }
    @flights << flight
    session[:success] = 'Flight information added.'
    redirect '/flights'
  end
end

get '/flights/add-southwest-flights' do
  erb :add_southwest_flights
end

post '/flights/add-southwest-flights' do
  airline = 'Southwest'
  flights_info = params[:southwest_flights_information]
  
  flights_info.gsub!("\r", '')
  
  origin_and_destination_info = flights_info[/Select Departing Flight:\s+(.+) to (.+)\s+Modify Search/]

  origin = $1
  destination = $2
  
  date_string = flights_info[/^.+(?= Selected Day\s+)/]
  date = Date.parse(date_string) if date_string
  
  flight_row_area = flights_info[/\d+:\d+ [AP]M.+(?=Price selected flight)/m]
  flight_rows = flight_row_area.split(/\n(?=\d+:\d+ [AP]M\s+\d+:\d+ [AP]M)/m)

  counter = 0
  
  flight_rows.each do |row|
    flight_numbers = row.scan(/\d+(?=\s\(opens popup\))/)
    flight_number = flight_numbers.join(", ");
    
    time_regex = /\d+:\d+\s[AP]M.?+Next Day|\d+:\d+\s[AP]M/m
    departure_time_string = row[time_regex]
    departure_time = Time.parse("#{date_string}, #{departure_time_string}")

    arrival_time_string = row.scan(time_regex)[1]

    arrival_time = Time.parse("#{date_string}, #{arrival_time_string}")
    next_day_arrival = arrival_time_string.include?("Next Day")
    arrival_time += 60 * 60 * 24 if next_day_arrival

    routing = row[/Nonstop|\d+ stop(s?).+\n.+/]
    routing = routing.sub(" (opens popup)", ", ")
                     .gsub(/[\r\n]/, '')

    travel_time = row[/\d+h\s\d+m/]
    
    price = row.scan(/\$\d+/)[-1]

    @errors = errors_for_flight(date_string, airline, flight_number, origin, destination, departure_time, arrival_time, price)

    if @errors.none?
      flight = {
        id: next_id(@flights),
        date: date,
        airline: airline,
        number: flight_number,
        origin: origin,
        destination: destination,
        departure_time: departure_time,
        arrival_time: arrival_time,
        next_day_arrival: next_day_arrival,
        routing: routing,
        travel_time: to_minutes(travel_time),
        price: price[1..-1].to_i
      }
      @flights << flight
      counter += 1
    end
  end

  session[:success] = "#{counter} flights added"
  
  redirect '/flights'
end

post '/flights/delete_all' do
  @flights = []
  session[:success] = 'Flights have all been deleted'
  redirect '/flights'
end

get '/flights/:id' do
  set_flight

  erb :flight
end

get '/flights/:id/edit' do
  set_flight

  erb :edit_flight
end

post '/flights/:id' do
  set_flight

  date = params[:date]
  airline = params[:airline].strip
  number = params[:number]
  origin = params[:origin].strip
  destination = params[:destination].strip
  departure_time = parse_time(params[:departure_time])
  arrival_time = parse_time(params[:arrival_time])
  next_day_arrival = (params[:next_day_arrival] == 'on')
  routing = params[:routing]
  travel_time = params[:travel_time]
  price = params[:price]

  @errors = errors_for_flight(date, airline, number, origin, destination, departure_time, arrival_time, price)

  if @errors.any?
    status 422
    session[:error] = erb(:flight_errors)
    erb :edit_flight
  else
    @flight[:date] = parse_date(date)
    @flight[:airline] = airline
    @flight[:number] = number
    @flight[:origin] = origin
    @flight[:destination] = destination
    @flight[:departure_time] = departure_time
    @flight[:arrival_time] = arrival_time
    @flight[:next_day_arrival] = next_day_arrival
    session[:success] = 'Flight information updated.'
    redirect '/flights'
  end
end

post '/flights/:id/delete' do
  set_flight
  @flights.delete(@flight)
  session[:success] = 'Flight deleted.'
  redirect '/flights'
end
