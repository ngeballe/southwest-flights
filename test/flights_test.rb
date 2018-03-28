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
    FileUtils.rm data_path
  end

  def flight_attributes
    {
      airline: 'Southwest',
      number: '268',
      origin: 'DCA',
      destination: 'SFO',
      departure_time: '6:00',
      arrival_time: '12:33',
      routing: '1 stop, Change Planes DEN',
      travel_time: '9h 35m',
      price: '$199'
    }
  end

  def session
    last_request.env["rack.session"]
  end

  def test_home_redirects_to_flights
    get '/'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal '/flights', last_request.env['PATH_INFO']
  end

  def test_flights_index
    post '/flights', flight_attributes

    get '/flights'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'New Flight'

    assert_includes last_response.body, 'Airline'
    assert_includes last_response.body, 'Flight Number'
    assert_includes last_response.body, 'Origin'
    assert_includes last_response.body, 'Destination'
    assert_includes last_response.body, 'Departure Time'
    assert_includes last_response.body, 'Arrival Time'
    assert_includes last_response.body, 'Routing'
    assert_includes last_response.body, 'Travel Time'
    assert_includes last_response.body, 'Price'

    assert_includes last_response.body, flight_attributes[:airline]
    assert_includes last_response.body, flight_attributes[:number]
    assert_includes last_response.body, flight_attributes[:origin]
    assert_includes last_response.body, flight_attributes[:destination]
    assert_includes last_response.body, flight_attributes[:departure_time]
    assert_includes last_response.body, flight_attributes[:arrival_time]
    assert_includes last_response.body, flight_attributes[:routing]
    assert_includes last_response.body, flight_attributes[:travel_time]
    assert_includes last_response.body, flight_attributes[:price]
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
    assert_includes last_response.body, %q(<input type="time" name="departure_time")
    assert_includes last_response.body, %q(<input type="time" name="arrival_time")
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

    [:airline, :number, :origin, :destination, :routing, :travel_time, :price].each do |attribute|
      assert_includes last_response.body, flight_attributes[attribute]
    end
  end

  def test_creating_second_flight
    post '/flights', flight_attributes.merge(airline: 'United')
    post '/flights', flight_attributes.merge(airline: 'another airline')

    get '/flights'

    assert_includes last_response.body, 'United'
    assert_includes last_response.body, 'another airline'
  end

  def test_create_flight_requires_airline
    post '/flights', flight_attributes.merge(airline: '  ')

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter the airline name.'

    assert_includes last_response.body, '  '
    assert_includes last_response.body, flight_attributes[:number]
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

  def test_show_multiple_errors_at_once
    post '/flights', flight_attributes.merge(airline: '', departure_time: '', destination: '')

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please enter the airline name.'
    assert_includes last_response.body, 'Please enter the departure time.'
    assert_includes last_response.body, 'Please enter the destination airport.'
  end

  def test_show_flight
    post '/flights', flight_attributes

    get '/flights/1'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
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
    assert_includes last_response.body, '12:33 PM'
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
    post '/flights', flight_attributes

    get '/flights/1'

    assert_includes last_response.body, %q(<a href="/flights/1/edit">Edit</a>)

    get '/flights/1/edit'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, %q(<input type="text" name="airline" value="Southwest")
    assert_includes last_response.body, %q(<input type="text" name="number" value="268")
    assert_includes last_response.body, %q(<input type="text" name="origin" value="DCA")
    assert_includes last_response.body, %q(<input type="text" name="destination" value="SFO")
    assert_includes last_response.body, %q(<input type="time" name="departure_time" value="06:00")
    assert_includes last_response.body, %q(<input type="time" name="arrival_time" value="12:33")
    assert_includes last_response.body, %q(<input type="text" name="routing" value="1 stop, Change Planes DEN")
    assert_includes last_response.body, %q(<input type="text" name="travel_time" value="9h 35m")
    assert_includes last_response.body, %q(<input type="text" name="price" value="$199")
  end

  def test_update_flight
    post '/flights', flight_attributes

    get '/flights/1'

    assert_includes last_response.body, 'Southwest'
    assert_includes last_response.body, '268'

    post '/flights/1', flight_attributes.merge(airline: 'Spirit', number: '999')

    assert_equal 302, last_response.status
    assert_equal 'Flight information updated.', session[:success]

    get '/flights/1'

    assert_includes last_response.body, 'Spirit'
    assert_includes last_response.body, '999'
    refute_includes last_response.body, 'Southwest'
    refute_includes last_response.body, '268'
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
    post '/flights', flight_attributes.merge(airline: 'CheapoAir')
    post '/flights', flight_attributes.merge(airline: 'JetBlue')

    get '/flights'

    assert_includes last_response.body, 'CheapoAir'
    assert_includes last_response.body, 'JetBlue'

    assert_includes last_response.body, 'Delete All Flights'

    post '/flights/delete_all'

    assert_equal 302, last_response.status
    assert_equal 'Flights have all been deleted', session[:success]

    get '/flights'

    refute_includes last_response.body, 'CheapoAir'
    refute_includes last_response.body, 'JetBlue'
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
    get '/flights'

    assert_includes last_response.body, %q(<a href="/flights/add-southwest-flights">Add Southwest Flights</a>)

    get '/flights/add-southwest-flights'

    assert_equal 200, last_response.status

    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']

    assert_includes last_response.body, %q(<textarea name="southwest_flights_information")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_parse_full_page_of_southwest_flights
    full_southwest_flight_information = <<~DOC
    Skip top navigation
     Español FLIGHT | HOTEL | CARSPECIAL OFFERSRAPID REWARDS®
    Search Flights Completed step  Select Flights Current step Price Remaining step Purchase Remaining step Confirmed Remaining step
    Select Departing Flight:
    Washington (Reagan National), DC to Seattle/Tacoma, WA
    Modify Search
    FlightRound Trip One-Way Additional Search Options
    From: Enter departure city or airport code
    Washington (Reagan National), DC - DCA
    To: Enter arrival city or airport code
    Seattle/Tacoma, WA - SEA
    +Add another flight
    First 2 Bags Fly Free®. Weight, size & excess limits apply. (opens new window) Gov't taxes & fees now included (opens popup)
    Change Depart trip date to APRIL 6, Friday
    APR
    6
    FRI
    Change Depart trip date to APRIL 7, Saturday
    APR
    7
    SAT
    Change Depart trip date to APRIL 8, Sunday
    APR
    8
    SUN
    Change Depart trip date to APRIL 9, Monday
    APR
    9
    MON
    Change Depart trip date to APRIL 10, Tuesday
    APR
    10
    TUE
    April 11, Wednesday Selected Day
    APR
    11
    WED
    Change Depart trip date to APRIL 12, Thursday
    APR
    12
    THU
    Change Depart trip date to APRIL 13, Friday
    APR
    13
    FRI
    Change Depart trip date to APRIL 14, Saturday
    APR
    14
    SAT
    Change Depart trip date to APRIL 15, Sunday
    APR
    15
    SUN
    Change Depart trip date to APRIL 16, Monday
    APR
    16
    MON
    Flexible Dates?
    Search the Low Fare Calendar
    Search now
    Filter My Results
      Filter My Results Direct (No plane change, with stops)
    Show fares in
    $ Show fares in $ selected Show fares in Points
    All fares are rounded up to the nearest dollar. Select departing flights and fares from the following table. Each flight may have multiple fares to choose from.
    Depart Flights are sorted in ascending order by Depart column Depart  Arrive Sortable column Arrive Flight number Sortable column Flight #  Routing Sortable column Routing Travel Time Sortable column Travel Time 
    Business Select Sortable column
    Business Select (opens popup)
    $613 - $617

    Anytime Sortable column
    Anytime (opens popup)
    $585 - $589

    Wanna Get Away Sortable column
    Wanna Get Away (opens popup)
    $147 - $346
    6:00 AM 
    11:00 AM
    5747 (opens popup) Connecting Flight
    1920 (opens popup)
    1 stop (opens popup)
    Change Planes MDW
    8h 00m
     $613
     $585
     $172
    6:45 AM 
    12:30 PM
    704 (opens popup) Connecting Flight
    1640 (opens popup)
    1 stop (opens popup)
    Change Planes DAL
    8h 45m
     $613
     $585
     $172
    8:00 AM 
    2:30 PM
    433 (opens popup) Connecting Flight
    5749 (opens popup)
    1 stop (opens popup)
    Change Planes MDW
    9h 30m
     $613
     $585
     $147
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
    11:40 AM  
    4:00 PM
    1969 (opens popup) Connecting Flight
    373 (opens popup)
    1 stop (opens popup)
    Change Planes STL
    7h 20m
     $613
     $585
    Sold Out
    11:40 AM  
    6:35 PM
    1969 (opens popup)
    2 stops (opens popup)
    No Plane Change
    9h 55m
     $613
     $585
    Sold Out
    11:50 AM  
    7:15 PM
    234 (opens popup) Connecting Flight
    5461 (opens popup)
    2 stops (opens popup)
    Change Planes DEN
    10h 25m
     $617
     $589
     $346
    4:00 PM 
    12:50 AM
    Next Day
    136 (opens popup) Connecting Flight
    676 (opens popup)
    2 stops (opens popup)
    Change Planes PHX
    11h 50m
     $617
     $589
     $257
    4:15 PM 
    12:20 AM
    Next Day
    678 (opens popup) Connecting Flight
    195 (opens popup)
    2 stops (opens popup)
    Change Planes LAS
    11h 05m
     $617
     $589
     $306
    5:45 PM 
    10:45 PM
    1672 (opens popup) Connecting Flight
    2070 (opens popup)
    1 stop (opens popup)
    Change Planes MDW
    8h 00m
     $613
     $585
     $252
    6:25 PM 
    12:30 AM
    Next Day
    5513 (opens popup) Connecting Flight
    309 (opens popup)
    2 stops (opens popup)
    Change Planes DEN
    9h 05m
     $617
     $589
     $306
    Price selected flight(s)
    Please read the Important Fare and Schedule Information available at the next heading, or continue.
    Important Fare & Schedule Information
    All fares and fare ranges are subject to change until purchased.
    Flight ontime performance statistics can be viewed by clicking on the individual flight numbers.
    All fares and fare ranges listed are per person for each way of travel.
    “Unavailable” indicates the corresponding fare is unavailable for the selected travel date(s), the search did not meet certain fare requirements, or the flight has already departed.
    “Sold Out” indicates that the flight is sold out for the corresponding fare type or the number of passengers in your reservation exceeds the number of remaining available seats for the corresponding fare type.
    “Invalid w/ Depart or Return Dates” indicates that our system cannot return a valid itinerary option(s) with the search criteria submitted. This can occur when flights are sold out in one direction of a roundtrip search or with a same-day roundtrip search. These itineraries may become valid options if you search with a different depart or return date and/or for a one way flight instead.
    “Travel Time” represents the total elapsed time for your trip from your departure city to your final destination including stops, layovers, and time zone changes.
    Along with our everyday low fares you may inquire about our discounts off the “Anytime” fare for infant, child (2-11), and military fares by calling 1-800-I-FLY-SWA (1-800-435-9792).
    Group Reservations: Ten or more Customers traveling from/to the same origin/destination. Discounts vary. Call 1-800-433-5368.
    *Savings based on Southwest Vacations Flight + Hotel package bookings of 5 or more nights on www.southwestvacations.com from June 1, 2015 through October 31, 2015, as compared to the price of the same components booked separately on southwest.com. Savings on any given package will vary based on the selected origin, destination, travel dates, number of passengers, hotel property, length of stay, car rental, and activity tickets. Savings may not be available on all packages.
    Quick Air Links
    Check In
    Change Flight
    Check Flight Status
    Account Login Enroll Now! To Rapid Rewards Program
    Username 
    235261854
    Password 
    ••••••••
     Remember Me Log In Need help logging in?  Manage Travel Section  Shopping Cart Section  Rapid Rewards Section

     Indicates external site which may or may not meet accessibility guidelines.

    © 2018 Southwest Airlines Co. All Rights Reserved. Use of the Southwest websites and our Company Information constitutes acceptance of our Terms and Conditions. Privacy Policy
      (opens popup)(opens new window)(opens popup)
    DOC

    post '/flights/add-southwest-flights', southwest_flights_information: full_southwest_flight_information

    assert_equal 302, last_response.status

    assert_equal '11 flights added', session[:success]

    get last_response['Location']

    assert_equal 200, last_response.status
    
    assert_equal '/flights', last_request.env['PATH_INFO']

    assert_includes last_response.body, 'Southwest'
    assert_includes last_response.body, 'Washington (Reagan National), DC'
    assert_includes last_response.body, 'Seattle/Tacoma, WA'
    assert_includes last_response.body, '6:00 AM'
    assert_includes last_response.body, '11:00 AM'
    assert_includes last_response.body, '5747, 1920'
    assert_includes last_response.body, '1 stop, Change Planes MDW'
    assert_includes last_response.body, '8h 00m'
    assert_includes last_response.body, '$172'

    assert_includes last_response.body, '704, 1640'
    assert_includes last_response.body, '6:45 AM'
    assert_includes last_response.body, '12:30 PM'
    assert_includes last_response.body, '1 stop, Change Planes DAL'
    assert_includes last_response.body, '8h 45m'
    assert_includes last_response.body, '$172'

    assert_includes last_response.body, '433, 5749'
    assert_includes last_response.body, '8:00 AM'
    assert_includes last_response.body, '2:30 PM'
    assert_includes last_response.body, '1 stop, Change Planes MDW'
    assert_includes last_response.body, '9h 30m'
    assert_includes last_response.body, '$147'

    assert_includes last_response.body, '787, 1148'
    assert_includes last_response.body, '9:00 AM'
    assert_includes last_response.body, '4:35 PM'
    assert_includes last_response.body, '1 stop, Change Planes MCI'
    assert_includes last_response.body, '10h 35m'
    assert_includes last_response.body, '$192'

    assert_includes last_response.body, '1969, 373'
    assert_includes last_response.body, '11:40 AM'
    assert_includes last_response.body, '4:00 PM'
    assert_includes last_response.body, '1 stop, Change Planes STL'
    assert_includes last_response.body, '7h 20m'
    assert_includes last_response.body, '$585'

    assert_includes last_response.body, '1969'
    assert_includes last_response.body, '11:40 AM'
    assert_includes last_response.body, '6:35 PM'
    assert_includes last_response.body, '2 stops, No Plane Change'
    assert_includes last_response.body, '9h 55m'
    assert_includes last_response.body, '$585'

    assert_includes last_response.body, '234, 5461'
    assert_includes last_response.body, '11:50 AM'
    assert_includes last_response.body, '7:15 PM'
    assert_includes last_response.body, '2 stops, Change Planes DEN'
    assert_includes last_response.body, '10h 25m'
    assert_includes last_response.body, '$346'

    assert_includes last_response.body, '136, 676'
    assert_includes last_response.body, '4:00 PM'
    assert_includes last_response.body, '12:50 AM'
    assert_includes last_response.body, '2 stops, Change Planes PHX'
    assert_includes last_response.body, '11h 50m'
    assert_includes last_response.body, '$257'

    assert_includes last_response.body, '678, 195'
    assert_includes last_response.body, '4:15 PM'
    assert_includes last_response.body, '12:20 AM'
    assert_includes last_response.body, '2 stops, Change Planes LAS'
    assert_includes last_response.body, '11h 05m'
    assert_includes last_response.body, '$306'

    assert_includes last_response.body, '1672, 2070'
    assert_includes last_response.body, '5:45 PM'
    assert_includes last_response.body, '10:45 PM'
    assert_includes last_response.body, '1 stop, Change Planes MDW'
    assert_includes last_response.body, '8h 00m'
    assert_includes last_response.body, '$252'

    assert_includes last_response.body, '5513, 309'
    assert_includes last_response.body, '6:25 PM'
    assert_includes last_response.body, '12:30 AM'
    assert_includes last_response.body, '2 stops, Change Planes DEN'
    assert_includes last_response.body, '9h 05m'
    assert_includes last_response.body, '$306'
  end
end
