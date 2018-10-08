ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'

require 'pp'

require_relative '../flights'

class FlightsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application.new
  end

  def setup   
  end

  def teardown
    post '/delete_all_data'
  end

  def flight_attributes
    {
      date: '2018-3-25',
      airline: 'Southwest',
      flight_number: '268',
      origin: 'DCA',
      destination: 'SFO',
      departure_time: '6:00',
      arrival_time: '12:33',
      routing: '1 stop, Change Planes DEN',
      travel_time: '9h 35m',
      price: '199'
    }
  end

  def session
    last_request.env["rack.session"]
  end

  def test_home_redirects_to_southwest_search_page1
    get '/'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal '/flights/southwest/find/pages/1', last_request.env['PATH_INFO']
  end

  def test_flights_index
    post '/flights', flight_attributes

    get '/flights'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'More Options'

    assert_includes last_response.body, 'Date'
    assert_includes last_response.body, 'Airline'
    assert_includes last_response.body, 'Flight Number'
    assert_includes last_response.body, 'Origin'
    assert_includes last_response.body, 'Destination'
    assert_includes last_response.body, 'Departure Time'
    assert_includes last_response.body, 'Arrival Time'
    assert_includes last_response.body, 'Routing'
    assert_includes last_response.body, 'Travel Time'
    assert_includes last_response.body, 'Price'

    assert_includes last_response.body, 'Sun., Mar. 25'
    assert_includes last_response.body, flight_attributes[:airline]
    assert_includes last_response.body, flight_attributes[:flight_number]
    assert_includes last_response.body, flight_attributes[:origin]
    assert_includes last_response.body, flight_attributes[:destination]
    assert_includes last_response.body, flight_attributes[:departure_time]
    assert_includes last_response.body, flight_attributes[:arrival_time]
    assert_includes last_response.body, flight_attributes[:routing]
    assert_includes last_response.body, flight_attributes[:travel_time]
    assert_includes last_response.body, flight_attributes[:price]
  end

  def test_flights_index_sort_by_price
    post '/flights', flight_attributes.merge(price: '300')
    post '/flights', flight_attributes.merge(flight_number: '2', price: '100')
    post '/flights', flight_attributes.merge(flight_number: '3', price: '200')

    get '/flights?sort=price'

    assert_equal 200, last_response.status

    assert_match /\$100.*\$200.*\$300/m, last_response.body
  end

  def test_flights_index_sort_by_duration
    post '/flights', flight_attributes.merge(flight_nubmer: '1001', travel_time: '10h 00m')
    post '/flights', flight_attributes.merge(flight_number: '1002', travel_time: '7h 20m')
    post '/flights', flight_attributes.merge(flight_number: '1003', travel_time: '8h 10m')

    get '/flights?sort=duration'

    assert_equal 200, last_response.status

    puts last_response.body

    # assert_match /7h 20m.*8h 10m.*10h 30m/m, last_response.body
  end

  def test_flights_index_sort_by_takeoff
    post '/flights', flight_attributes.merge(flight_number: '1', departure_time: '8:45 AM')
    post '/flights', flight_attributes.merge(flight_number: '2', departure_time: '1:39 PM')
    post '/flights', flight_attributes.merge(flight_number: '3', departure_time: '9:05 AM')

    get '/flights?sort=takeoff'

    assert_equal 200, last_response.status

    assert_match /8:45 AM.*9:05 AM.*1:39 PM/m, last_response.body
  end

  def test_flights_index_sort_by_landing
    post '/flights', flight_attributes.merge(flight_number: '1', arrival_time: '8:45 AM')
    post '/flights', flight_attributes.merge(flight_number: '2', arrival_time: '1:39 PM')
    post '/flights', flight_attributes.merge(flight_number: '3', arrival_time: '9:05 AM')

    get '/flights?sort=landing'

    assert_equal 200, last_response.status

    assert_match /8:45 AM.*9:05 AM.*1:39 PM/m, last_response.body
  end

  def test_flights_index_sorts_next_day_arrivals_correctly
    post '/flights', flight_attributes.merge(flight_number: '1', arrival_time: '8:45 AM')
    post '/flights', flight_attributes.merge(flight_number: '2', arrival_time: '1:39 PM')
    post '/flights', flight_attributes.merge(flight_number: '3', arrival_time: '9:05 AM')
    post '/flights', flight_attributes.merge(flight_number: '4', arrival_time: '0:55', next_day_arrival: 'on')

    get '/flights?sort=landing'

    puts last_response.body

    # assert_match /8:45 AM.*9:05 AM.*1:39 PM.*12:55 AM next day/m, last_response.body
  end

  def test_new_flight
    get '/flights/new'
    
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']

    assert_includes last_response.body, "New Flight"
    assert_includes last_response.body, %q(<input type="text" name="airline")
    assert_includes last_response.body, %q(<input type="text" name="number")
    assert_includes last_response.body, %q(<input type="text" name="origin")
    assert_includes last_response.body, %q(<input type="text" name="destination")
    assert_includes last_response.body, %q(<input type="date" name="date")
    assert_includes last_response.body, %q(<input type="time" name="departure_time")
    assert_includes last_response.body, %q(<input type="time" name="arrival_time")
    assert_includes last_response.body, %q(<input type="checkbox" name="next_day_arrival")
    assert_includes last_response.body, %q(<input type="text" name="routing")
    assert_includes last_response.body, %q(<input type="text" name="travel_time")
    assert_includes last_response.body, %q(<input type="text" name="price")
    assert_includes last_response.body, %q(<button type="submit">Save</button>)
  end

  def test_create_flight
    post '/flights', flight_attributes

    assert_equal 302, last_response.status
    assert_equal 'Flight information added.', session[:success]

    get last_response['Location']

    [:airline, :flight_number, :origin, :destination, :departure_time, :arrival_time, :routing, :travel_time, :price].each do |attribute|
      assert_includes last_response.body, flight_attributes[attribute]
    end

    assert_includes last_response.body, 'Sun., Mar. 25'
  end

  def test_creating_second_flight
    post '/flights', flight_attributes.merge(flight_number: '111')
    post '/flights', flight_attributes.merge(flight_number: '222')

    get '/flights'

    assert_includes last_response.body, '111'
    assert_includes last_response.body, '222'
  end

  def test_create_flight_requires_valid_date
    post '/flights', flight_attributes.merge(date: 'never')

    assert_equal 422, last_response.status

    assert_includes last_response.body, 'Invalid date.'
  end

  def test_create_flight_requires_airline
    post '/flights', flight_attributes.merge(airline: '  ')

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter the airline name.'

    assert_includes last_response.body, '  '
    assert_includes last_response.body, flight_attributes[:flight_number]
    assert_includes last_response.body, flight_attributes[:destination]
    assert_includes last_response.body, flight_attributes[:departure_time]
  end

  def test_create_flight_requires_origin
    post '/flights', flight_attributes.merge(origin: '')

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Please enter the airport you're departing from."
  end

  def test_create_flight_requires_destination
    post '/flights', flight_attributes.merge(destination: '')

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter the destination airport.'
  end

  def test_create_flight_requires_departure_time
    post '/flights', flight_attributes.merge(departure_time: '')

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter the departure time.'
  end

  def test_create_flight_requires_price
    post '/flights', flight_attributes.merge(price: '')

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter the price.'
  end

  def test_create_flight_validates_for_flight_uniqueness
    post '/flights', flight_attributes

    assert_equal 302, last_response.status

    post '/flights', flight_attributes

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'That flight is already on your list.'
  end

  def test_show_multiple_errors_at_once
    post '/flights', flight_attributes.merge(airline: '', departure_time: '', destination: '')

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter the airline name.'
    assert_includes last_response.body, 'Please enter the departure time.'
    assert_includes last_response.body, 'Please enter the destination airport.'
  end

  def test_show_flight
    post '/flights', flight_attributes.merge(next_day_arrival: 'on')

    get '/flights/1'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Date'
    assert_includes last_response.body, 'Sun., Mar. 25'
    assert_includes last_response.body, 'Airline'
    assert_includes last_response.body, 'Southwest'
    assert_includes last_response.body, 'Flight Number'
    assert_includes last_response.body, '268'
    assert_includes last_response.body, 'Origin'
    assert_includes last_response.body, 'DCA'
    assert_includes last_response.body, 'Destination'
    assert_includes last_response.body, 'SFO'
    assert_includes last_response.body, 'Departure Time'
    assert_includes last_response.body, '6:00 AM'
    assert_includes last_response.body, 'Arrival Time'
    assert_includes last_response.body, '12:33 PM next day'
    assert_includes last_response.body, 'Routing'
    assert_includes last_response.body, '1 stop, Change Planes DEN'
    assert_includes last_response.body, 'Travel Time'
    assert_includes last_response.body, '9h 35m'
    assert_includes last_response.body, 'Price'
    assert_includes last_response.body, '$199'

    assert_includes last_response.body, %q(<a href="/">)
  end

  def test_show_flight_displays_12_hour_times
    post '/flights', flight_attributes.merge(departure_time: '2:30 PM', arrival_time: '8:30 PM')

    get '/flights/1'

    assert_includes last_response.body, '2:30 PM'
    assert_includes last_response.body, '8:30 PM'
  end

  def test_edit_flight
    post '/flights', flight_attributes.merge(arrival_time: '00:05', next_day_arrival: 'on')

    get '/flights/1'

    assert_includes last_response.body, %q(<a href="/flights/1/edit">Edit</a>)

    get '/flights/1/edit'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %q(<input type="date" name="date" value="2018-03-25")
    assert_includes last_response.body, %q(<input type="text" name="airline" value="Southwest")
    assert_includes last_response.body, %q(<input type="text" name="flight_number" value="268")
    assert_includes last_response.body, %q(<input type="text" name="origin" value="DCA")
    assert_includes last_response.body, %q(<input type="text" name="destination" value="SFO")
    assert_includes last_response.body, %q(<input type="time" name="departure_time" value="06:00")
    assert_includes last_response.body, %q(<input type="time" name="arrival_time" value="00:05")
    assert_includes last_response.body, %q(<input type="checkbox" name="next_day_arrival" id="next_day_arrival" checked)
    assert_includes last_response.body, %q(<input type="text" name="routing" value="1 stop, Change Planes DEN")
    assert_includes last_response.body, %q(<input type="text" name="travel_time" value="9h 35m")
    assert_includes last_response.body, %q(<input type="text" name="price" value="199")
  end

  def test_update_flight
    post '/flights', flight_attributes.merge(next_day_arrival: 'on')

    get '/flights/1'

    assert_includes last_response.body, 'Southwest'
    assert_includes last_response.body, 'next day'
    assert_includes last_response.body, '268'

    post '/flights/1', flight_attributes.merge(flight_number: '999', date: '2018-1-1', next_day_arrival: '')

    assert_equal 302, last_response.status
    assert_equal 'Flight information updated.', session[:success]

    get '/flights/1'

    assert_includes last_response.body, '999'
    assert_includes last_response.body, 'Mon., Jan. 1'
    
    refute_includes last_response.body, '268'
    refute_includes last_response.body, 'next day'
  end

  def test_update_flight_validates
    post '/flights', flight_attributes

    post '/flights/1', flight_attributes.merge(price: '')

    assert_equal 422, last_response.status

    assert_includes last_response.body, 'Please enter the price.'
  end

  def test_update_flight_validates_uniqueness
    post '/flights', flight_attributes.merge(flight_number: '111')
    post '/flights', flight_attributes.merge(flight_number: '222')

    post '/flights/2', flight_attributes.merge(flight_number: '111')

    assert_equal 422, last_response.status

    assert_includes last_response.body, 'That flight is already on your list.'
  end

  def test_update_flight_without_changing_information_valid
    post '/flights', flight_attributes

    post '/flights/1', flight_attributes

    assert_equal 'Flight information updated.', session[:success]

    assert_equal 302, last_response.status
  end

  def test_updating_flight_does_not_require_date
    skip
  end

  def test_delete_flight
    post '/flights', flight_attributes

    get '/flights'

    assert_includes last_response.body, flight_attributes[:origin]

    get '/flights/1'

    assert_includes last_response.body, %q(<button type="submit">Delete</button>)

    post '/flights/1/delete'

    assert_equal 302, last_response.status
    assert_equal 'Flight deleted.', session[:success]

    get '/flights'

    refute_includes last_response.body, flight_attributes[:origin]
  end

  def test_delete_all_flights
    post '/flights', flight_attributes.merge(flight_number: '123')
    post '/flights', flight_attributes.merge(flight_number: '456')

    get '/flights'

    assert_includes last_response.body, '123'
    assert_includes last_response.body, '456'

    assert_includes last_response.body, 'Delete All Flights'

    post '/flights/delete_all'

    assert_equal 302, last_response.status
    assert_equal 'Flights have all been deleted', session[:success]

    get '/flights'

    refute_includes last_response.body, '123'
    refute_includes last_response.body, '456'
  end

  def test_parse_southwest_flight_information
    skip
    southwest_flight_information = <<~DOC
      9:00 AM 
      4:35 PM
      787 (opens popup) Connecting Flight
      1148 (opens popup)
      1 stop (opens popup)
      Change Planes MCI
      10h 35m
       $613
       $585
       $192
    DOC
    get '/flights/new'

    assert_includes last_response.body, 'Southwest Flight'
    assert_includes last_response.body, %q(<textarea name="southwest_flight")

    post '/flights', southwest_flight: southwest_flight_information

    pp last_response

    assert_equal 302, last_response.status
    assert_equal 'Flight information added.', session[:success]
    
    get '/flights'

    assert_includes last_response.body, 'Southwest'
    assert_includes last_response.body, '268'
    assert_includes last_response.body, 'SFO'
    assert_includes last_response.body, '6:00 AM'

    assert_includes last_response.body, '$192'
  end

  def test_page_to_add_multiple_southwest_flights
    get '/flights/add-southwest-flights'

    assert_equal 200, last_response.status

    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']

    assert_includes last_response.body, %q(<textarea name="southwest_flights_information")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_parse_full_page_of_southwest_flights
    full_southwest_flight_information = <<~DOC
    Skip to content
    Log inUnlock headerEspañol
    DEC 3
    SEA  DCAModify
    Depart: SEADCA
    Seattle/Tacoma, WA - SEA to Washington (Reagan National), DC - DCA
    Government taxes & fees included
    All fares are rounded up to the nearest dollar.

    $Points
    SAT
    Dec 01
    SUN
    Dec 02
    MON
    Dec 03
    TUE
    Dec 04
    WED
    Dec 05
    Low Fare CalendarFirst 2 bags fly free®Weight, size & excess limits apply
    Sort by

    Departure time
    View fare type benefits
    Departing flights = Change planes
    Business Select
    Anytime
    Wanna Get Away
    # 1800 / 9102 stops
    5:10AM6:35PMDuration
    10h 25m
    2 stops
    OAK2h 0m
    STL0h 50m
    $627$599$181
    1 left
    # 2219 / 3122 stops
    5:50AM5:15PMDuration
    8h 25m
    2 stops
    DEN1h 35m
    OMA0h 40m
    $627$599$141
    # 1791 / 1361 stop
    6:35AM6:15PMDuration
    8h 40m
    1 stop
    MDW3h 0m
    $623$595$137
    # 1797 / 13381 stop
    8:00AM8:35PMDuration
    9h 35m
    1 stop
    MCI3h 50m
    $623$595$137
    # 2258 / 9101 stop
    9:20AM6:35PMDuration
    6h 15m
    1 stop
    STL0h 40m
    $623$595$137
    1 left
    # 2258 / 1452 stops
    9:20AM9:20PMDuration
    9h 0m
    2 stops
    STL1h 20m
    MKE1h 0m
    $627$599$188
    3 left
    # 2329 / 16872 stops
    9:20AM11:25PMDuration
    11h 5m
    2 stops
    OAK1h 55m
    HOU0h 45m
    $627$599$290
    Continue
    Important fare and schedule information
    All fare and fare ranges are subject to change until purchased.
    Flight ontime performance statistics can be viewed by clicking on the individual flight numbers.
    All fare and fare ranges listed are per person for each way of travel.
    "Unavailable" indicates the corresponding fare is unavailable for the selected dates, the search did not meet certain fare requirements, or the flight has already departed.
    “Sold Out" indicates that, based on the number of travelers in your search, we do not have seats for all of those travelers in the particular fare type.
    "Invalid w/ Depart or Return Dates" indicates that our system cannot return a valid itinerary option(s) with the search criteria submitted. This can occur when flights are sold out in one direction of a round trip search or with a same-day round trip search. These itineraries may become valid options if you search with a different depart or return date and/or for a one-way flight instead.
    For infant, child (2-11) and military fares please call 1-800-I-FLY-SWA (1-800-435-9792). These fares are a discount off the "Anytime" fares. Other fares may be lower.
    Group Reservations, Ten or more Customers traveling from/to the same origin/destination. Discounts vary. Call 1-800-433-5368
    "Savings with Flight + Hotel" claim is based on average savings for Southwest Vacations bookings purchased in a bundled package of 5 or more nights vs purchasing components separately (i.e: a la carte). Savings on any given package will vary based on the selected origin, destination, travel dates, hotel property, length of stay, car rental, and activity tickets. Savings may not be available on all packages.
    Indicates external site which may or may not meet accessibility guidelines© 2018 Southwest Airlines Co. All Rights Reserved. Use of the Southwest websites and our Company Information constitutes acceptance of our Terms and Conditions. Privacy Policy
    DOC

    post '/flights/add-southwest-flights', southwest_flights_information: full_southwest_flight_information

    assert_equal 302, last_response.status

    assert_equal '7 flights added', session[:success]

    get last_response['Location']

    assert_equal 200, last_response.status
    
    assert_equal '/flights', last_request.env['PATH_INFO']

    puts last_response.body

    assert_includes last_response.body, '<td>Southwest</td>'
    assert_includes last_response.body, '<td>DCA</td>'
    assert_includes last_response.body, '<td>SEA</td>'
    assert_includes last_response.body, '<td>Mon., Dec. 3</td>'

    assert_includes last_response.body, '<td>1800, 910</td>'
    assert_includes last_response.body, '<td>5:10 AM</td>'
    assert_includes last_response.body, '<td>6:35 AM</td>'
    assert_includes last_response.body, '<td>2 stops</td>'
    assert_includes last_response.body, '<td>10h 25m</td>'
    assert_includes last_response.body, '<td>$181</td>'

    assert_includes last_response.body, '<td>2219, 312</td>'
    assert_includes last_response.body, '<td>5:50 AM</td>'
    assert_includes last_response.body, '<td>5:15 PM</td>'
    assert_includes last_response.body, '<td>2 stops</td>'
    assert_includes last_response.body, '<td>8h 25m</td>'
    assert_includes last_response.body, '<td>$141</td>'

    assert_includes last_response.body, '<td>1791, 136</td>'
    assert_includes last_response.body, '<td>6:35 AM</td>'
    assert_includes last_response.body, '<td>6:15 PM</td>'
    assert_includes last_response.body, '<td>1 stop</td>'
    assert_includes last_response.body, '<td>8h 25m</td>'
    assert_includes last_response.body, '<td>$137</td>'

    assert_includes last_response.body, '<td>1797, 1338</td>'
    assert_includes last_response.body, '<td>8:00 AM</td>'
    assert_includes last_response.body, '<td>8:35 PM</td>'
    assert_includes last_response.body, '<td>1 stop</td>'
    assert_includes last_response.body, '<td>9h 35m</td>'
    assert_includes last_response.body, '<td>$137</td>'

    assert_includes last_response.body, '<td>2258, 910</td>'
    assert_includes last_response.body, '<td>9:20 AM</td>'
    assert_includes last_response.body, '<td>6:35 PM</td>'
    assert_includes last_response.body, '<td>1 stop</td>'
    assert_includes last_response.body, '<td>6h 15m</td>'
    assert_includes last_response.body, '<td>$137</td>'

    assert_includes last_response.body, '<td>2258, 145</td>'
    assert_includes last_response.body, '<td>9:20 AM</td>'
    assert_includes last_response.body, '<td>9:20 PM</td>'
    assert_includes last_response.body, '<td>2 stops</td>'
    assert_includes last_response.body, '<td>9h 00m</td>'
    assert_includes last_response.body, '<td>$188</td>'

    assert_includes last_response.body, '<td>2329, 1687</td>'
    assert_includes last_response.body, '<td>9:20 AM</td>'
    assert_includes last_response.body, '<td>11:25 PM</td>'
    assert_includes last_response.body, '<td>2 stops</td>'
    assert_includes last_response.body, '<td>11h 05m</td>'
    assert_includes last_response.body, '<td>$290</td>'
  end

  def test_submitting_southwest_flights_with_no_data
    post '/flights/add-southwest-flights', southwest_flights_information: ''

    assert_equal 302, last_response.status

    assert_equal 'Invalid data.', session[:error]
    get last_response['Location']

    assert_includes last_response.body, 'Invalid data.'
  end

  def test_filter_by_price
    skip
    post '/flights', flight_attributes.merge(price: '$300')
    post '/flights', flight_attributes.merge(price: '$100')
    post '/flights', flight_attributes.merge(price: '$200')

    get '/flights?sort=price&maxPrice=200'

    assert_equal 200, last_response.status

    assert_match /\$100.*\$200.*/m, last_response.body
  end
end
