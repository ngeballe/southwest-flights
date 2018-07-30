require 'sinatra'
require 'sinatra/reloader' if development?
require 'yaml/store'
require 'tilt/erubis'
require 'pry'

CITY_OPTIONS = [ 
                 'Seattle (SEA)',
                 'San Francisco Bay Area (OAK, SFO, SJC)',
                 'Washington, D.C. (DCA, BWI, IAD)'
               ]

module Southwest
  FLIGHT_ROW_AREA_START = /(?<=Wanna Get Away\n).+/im
  FLIGHT_ROW_DELIMITER = /\n(?=#\s?\d+)/
  FLIGHT_NUMBER_REGEX = /(?<=^#\s).+(?=Nonstop|\d+ stop)/
end

configure do
  enable :sessions
  set :session_secret, 'd898w98vf8909sidfuiqwuopffdlcxksjiowqu97ncjh7282'
end

before do
  @store = YAML::Store.new data_path
  @store.transaction do
    @flights = @store[:flights] || []
  end
  session[:southwest_query_data] ||= []
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
    arrival_time_string << ' next day' if flight[:next_day_arrival]
    arrival_time_string
  end

  def format_travel_time(flight)
    hours, minutes = flight[:travel_time].divmod(60)
    format('%dh %02dm', hours, minutes)
  end

  def highlight_class(sort_type)
    if params[:sort] == sort_type
      'highlighted'
    else
      ''
    end
  end

  def month_number(month_name)
    Date::MONTHNAMES.index(month_name)
  end

  def selected_if_true(expression)
    expression ? 'selected' : ''
  end

  def southwest_query_url(data)
    search_url = "https://www.southwest.com/air/booking/select.html?"
    search_url << "originationAirportCode=#{data[:origin]}"
    search_url << "&destinationAirportCode=#{data[:destination]}"
    search_url << "&returnAirportCode=&departureDate=#{data[:date_string]}"
    search_url << <<~DOC.strip
    &departureTimeOfDay=ALL_DAY&returnDate=&returnTimeOfDay=ALL_DAY&adultPassengersCount=1&seniorPassengersCount=0&fareType=USD&passengerType=ADULT&tripType=oneway&promoCode=&reset=true&redirectToVision=true&int=HOMEQBOMAIR&leapfrogRequest=true
    DOC
  end

  def southwest_query_link_text(data)
    "Flights from #{data[:origin]} to #{data[:destination]} on #{data[:date_string]}"
  end

  def options_for_select(option_array, prompt = 'Choose one')
    option_array = [prompt] + option_array if prompt
    option_array.reduce('') do |html, option|
      html + "<option>#{option}</option>"
    end
  end
end

FLIGHT_ATTRIBUTES = ['Date', 'Airline', 'Flight Number', 'Origin', 'Destination', 'Departure Time', 'Arrival Time', 'Routing', 'Travel Time', 'Price']

def data_path
  if ENV['RACK_ENV'] == 'test'
    'test/data.yml'
  else
    'data.yml'
  end
end

def errors_for_flight(flight)
  errors = []
  errors << 'Invalid date.' if flight[:date].nil?
  errors << 'Please enter the airline name.' if flight[:airline].empty?
  errors << "Please enter the airport you're departing from." if flight[:origin].empty?
  errors << 'Please enter the destination airport.' if flight[:destination].empty?
  errors << 'Please enter the departure time.' if flight[:departure_time] == ''
  errors << 'Please enter the arrival time' if flight[:arrival_time] == ''
  errors << 'Please enter the price.' if ['', nil].include?(flight[:price])
  errors << 'That flight is already on your list.' unless flight_unique?(flight)
  errors
end

def invalid_date?(flight)
  flight[:date] 
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

def price_as_integer(price)
  if price && !price.empty?
    price = price[1..-1].to_i
  else
    price = nil
  end
end

def flight_unique?(flight)
  @flights.none? do |existing_flight|
    # existing_flight
    # all but ID same?
    same_values_except_id?(flight, existing_flight)
  end
end

def same_values_except_id?(flight1, flight2)
  return false if flight1[:id] == flight2[:id]
  flight1_attributes = flight1.reject { |k, v| k == :id }
  flight2_attributes = flight2.reject { |k, v| k == :id }
  flight1_attributes == flight2_attributes
end

def parse_flight_from_southwest_page_row(row, origin, destination, date_string)
  date = Date.parse(date_string) if date_string

  flight_numbers = row.scan(Southwest::FLIGHT_NUMBER_REGEX)
  flight_number = flight_numbers.join(', ')

  time_regex = /\d+:\d+\s?[AP]M.?+Next Day|\d+:\d+\s?[AP]M/m
  departure_time_string = row[time_regex]
  departure_time = Time.parse("#{date_string}, #{departure_time_string}")

  arrival_time_string = row.scan(time_regex)[1]

  arrival_time = Time.parse("#{date_string}, #{arrival_time_string}")

  next_day_arrival = row.include?('Next Day')
  arrival_time += 60 * 60 * 24 if next_day_arrival

  routing = row[/Nonstop|\d stop(s?)\n?/i]

  routing = if routing
              routing.strip.gsub(/[\r\n]/, ', ')
            else
              'Nonstop'
            end

  travel_time = row[/\d+h\s\d+m/]

  price = row.scan(/\$\d+/)[-1] || ''
  return if price.empty?

  {
    id: next_id(@flights),
    date: date,
    airline: 'Southwest',
    number: flight_number,
    origin: origin,
    destination: destination,
    departure_time: departure_time,
    arrival_time: arrival_time,
    next_day_arrival: next_day_arrival,
    routing: routing,
    travel_time: to_minutes(travel_time),
    price: Integer(price[1..-1])
  }
end

def flight_params
  {
    date: parse_date(params[:date]),
    airline: params[:airline].strip,
    number: params[:number],
    origin: params[:origin].strip,
    destination: params[:destination].strip,
    departure_time: parse_time(params[:departure_time]),
    arrival_time: parse_time(params[:arrival_time]),
    next_day_arrival: (params[:next_day_arrival] == 'on'),
    routing: params[:routing],
    travel_time: to_minutes(params[:travel_time]),
    price: price_as_integer(params[:price])
  }
end

def parse_origin_and_destination(southwest_flights_info)
  southwest_flights_info[/.+([A-Z]{3}) to .+([A-Z]{3})/]
  # origin = $1
  origin = Regexp.last_match[1]
  # destination = $2
  destination = Regexp.last_match[2]

  [origin, destination]
end

def flight_rows(southwest_flights_info)
  flight_row_area = southwest_flights_info[Southwest::FLIGHT_ROW_AREA_START]

  flight_row_area.split(Southwest::FLIGHT_ROW_DELIMITER)
end

def date_for_southwest_query(month, day, year)
  format('%4d-%02d-%02d', year, month, day)
end

get '/' do
  redirect '/flights'
end

get '/flights' do
  @current_year = Date.today.year
  @current_month_name = Date.today.strftime('%B')
  @southwest_query_data = session[:southwest_query_data] || []

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
  flight = flight_params.merge(id: next_id(@flights))

  @errors = errors_for_flight(flight)
  if @errors.any?
    status 422
    session[:error] = erb :flight_errors, layout: nil
    erb :new_flight
  else
    @flights << flight
    session[:success] = 'Flight information added.'
    redirect '/flights'
  end
end

get '/flights/add-southwest-flights' do
  erb :add_southwest_flights
end

post '/flights/add-southwest-flights' do
  flights_info = params[:southwest_flights_information]

  if flights_info.strip.empty?
    status 422
    session[:error] = 'Invalid data.'
    redirect '/flights'
  end

  flights_info.delete!("\r")

  origin, destination = parse_origin_and_destination(flights_info)

  date_string = flights_info[/^[A-Z]{3}\s\d{1,2}$/]

  counter = 0

  flight_rows(flights_info).each do |row|
    flight = parse_flight_from_southwest_page_row(row, origin,
                                                  destination,
                                                  date_string)
    next unless flight

    @errors = errors_for_flight(flight)
    if @errors.none?
      @flights << flight
      counter += 1
    end
  end

  if counter.zero?
    session[:error] = '0 flights added'
  else
    session[:success] = "#{counter} flights added"
  end

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

  flight = @flight.merge(flight_params)

  @errors = errors_for_flight(flight)

  if @errors.any?
    status 422
    session[:error] = erb :flight_errors, layout: nil
    erb :edit_flight
  else
    @flight.merge!(flight)
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

get '/options' do
  erb :options
end

post '/southwest_searches' do
  month = params[:month]
  day = params[:day]
  year = params[:year]
  departure_airports = params[:departure_airports].split(",")
                                                  .map(&:upcase)
  arrival_airports = params[:arrival_airports].split(",")
                                                .map(&:upcase)
  combinations = departure_airports.product(arrival_airports)
  date = date_for_southwest_query(month, day, year)

  combinations.each do |departure_airport, arrival_airport|
    data_for_one_query = {
      origin: departure_airport,
      destination: arrival_airport,
      date_string: date
    }
    session[:southwest_query_data] << data_for_one_query
  end

  redirect '/flights'
end

post '/southwest_query_data/delete' do
  session[:southwest_query_data].clear
  redirect '/flights'
end
