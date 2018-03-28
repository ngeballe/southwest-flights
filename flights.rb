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

  # @flights = session[:flights] || []
end

after do
  # session[:flights] = @flights
  @store.transaction do
    @store[:flights] = @flights
  end
end

helpers do
end

FLIGHT_ATTRIBUTES = ['Airline', 'Flight Number', 'Origin', 'Destination', 'Departure Time', 'Arrival Time', 'Routing', 'Travel Time', 'Price']

def data_path
  if ENV["RACK_ENV"] == "test"
    'test/data.yml'
  else
    'data.yml'
  end
end

def errors_for_flight(airline, number, origin, destination, departure_time)
  errors = []
  errors << "Please enter the airline name." if airline.empty?
  errors << "Please enter the airport you're departing from." if origin.empty?
  errors << "Please enter the destination airport." if destination.empty?
  errors << "Please enter the departure time." if departure_time == ''
  errors
end

def set_flight
  @flight = @flights.detect { |flight| flight[:id] == params[:id].to_i }
end

def parse_time(time_string)
  if time_string.empty?
    ''
  else
    Time.parse(time_string)
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

get '/' do
  redirect '/flights'
end

get '/flights' do
  erb :flights
end

get '/flights/new' do
  erb :new_flight
end

post '/flights' do
  airline = params[:airline].strip
  number = params[:number]
  origin = params[:origin].strip
  destination = params[:destination].strip
  departure_time = parse_time(params[:departure_time])
  arrival_time = parse_time(params[:arrival_time])
  routing = params[:routing]
  travel_time = params[:travel_time]
  price = params[:price]

  @errors = errors_for_flight(airline, number, origin, destination, departure_time)
  if @errors.any?
    status 422
    session[:error] = erb(:flight_errors)
    erb :new_flight
  else
    flight = {
      id: next_id(@flights),
      airline: airline,
      number: number,
      origin: origin,
      destination: destination,
      departure_time: departure_time,
      arrival_time: arrival_time,
      routing: routing,
      travel_time: travel_time,
      price: price
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
  origin_and_destination_info = flights_info[/Select Departing Flight:\s+(.+) to (.+)\s+Modify Search/]

  origin = $1
  destination = $2
  
  date_string = flights_info[/^.+(?= Selected Day\s+)/]
  date = Date.parse(date_string)
  
  flight_row_area = flights_info[/\d+:\d+ [AP]M.+(?=Price selected flight)/m]
  flight_rows = flight_row_area.split(/\n(?=\d+:\d+ [AP]M\s+\d+:\d+ [AP]M)/m)

  counter = 0
  
  flight_rows.each do |row|    
    flight_numbers = row.scan(/\d+(?=\s\(opens popup\))/)
    flight_number = flight_numbers.join(", ");
    
    time_regex = /\d+:\d+\s[AP]M/
    departure_time_string = row[time_regex]
    departure_time = Time.parse(departure_time_string)

    arrival_time_string = row.scan(time_regex)[1]
    arrival_time = Time.parse(arrival_time_string)

    routing = row[/\d+ stop(s?).+\n.+/]
    routing.sub!(" (opens popup)", ", ")
           .gsub!(/[\r\n]/, '')

    travel_time = row[/\d+h\s\d+m/]
    
    price = row.scan(/\$\d+/)[-1]

    @errors = errors_for_flight(airline, flight_number, origin, destination, departure_time)
    
    if @errors.any?
      throw @errors
      status 422
      session[:error] = erb(:flight_errors)
      erb :add_southwest_flights
    else
      flight = {
        id: next_id(@flights),
        airline: airline,
        number: flight_number,
        origin: origin,
        destination: destination,
        departure_time: departure_time,
        arrival_time: arrival_time,
        routing: routing,
        travel_time: travel_time,
        price: price
      }
      # throw flight
      # @flights << flight
      # @flights << flight
      @flights << flight
    end

    counter += 1
  end

  session[:success] = "#{flight_rows.size} flights added"
  
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

  airline = params[:airline].strip
  number = params[:number]
  origin = params[:origin].strip
  destination = params[:destination].strip
  departure_time = parse_time(params[:departure_time])
  arrival_time = parse_time(params[:arrival_time])
  routing = params[:routing]
  travel_time = params[:travel_time]
  price = params[:price]

  @errors = errors_for_flight(airline, number, origin, destination, departure_time)
  if @errors.any?
    status 422
    session[:error] = erb(:flight_errors)
    erb :edit_flight
  else
    @flight[:airline] = airline
    @flight[:number] = number
    @flight[:destination] = destination
    @flight[:departure_time] = departure_time
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
