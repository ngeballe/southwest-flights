$(function() {
  $('form.delete').submit(function(event) {
    event.preventDefault();
    event.stopPropagation();
    
    var ok = confirm('Are you sure you want to delete it? This cannot be undone.');

    if (ok) {
      this.submit();
    }
  });

  $('form#generate_southwest_links').submit(function(event) {
    // event.preventDefault()
    event.preventDefault();
    event.stopPropagation();
    if ($('#departure_airports').val() == '') {
      alert('You must choose at least one departure airport or city.');
    } else if ($('#arrival_airports').val() == '') {
      alert('You must choose at least one arrival airport or city.');
    } else {
      this.submit();
    }
  });

  $('textarea#southwest_flight').blur(function() {
    var text = $('#southwest_flight').val();

    $('#airline').val('Southwest');

    var flight_numbers = text.match(/\d+(?=\s\(opens popup\))/g);
    var flight_number = flight_numbers.join(", ");
    $('#number').val(flight_number);

    var departure_time_string = text.match(/\d+:\d+\s[AP]M/)[0];
    var departure_time_converted = convert_to_time_format(departure_time_string);
    $('#departure_time').val(departure_time_converted);
    
    var arrival_time_string = text.match(/\d+:\d+\s[AP]M(\s+Next Day)?/g)[1];
    var arrival_time_string_converted = convert_to_time_format(arrival_time_string);
    $('#arrival_time').val(arrival_time_string_converted);
    if (arrival_time_string.includes("Next Day")) {
      $("#next_day_arrival").attr('checked', true);
    }

    var routing = text.match(/\d+ stop(s?).+\n.+/)[0];
    routing = routing.replace(" (opens popup)", ", ");
    routing = routing.replace(/[\r\n]/g, '');
    $('#routing').val(routing);

    var travel_time = text.match(/\d+h\s\d+m/)[0];
    $('#travel_time').val(travel_time);
    
    var prices = text.match(/\$\d+/g);
    var price = prices[prices.length - 1];

    $('#price').val(price);
  });

  $('select#departure_city').change(function() {
    put_airports_in_input(this, '#departure_airports');
  });

  $('select#arrival_city').change(function() {
    put_airports_in_input(this, '#arrival_airports');
  });

  // $('button#sort_by_price').click(function(event) {
  //   event.preventDefault();
  //   event.stopPropagation();
  //   $('input#sort').val('price');
  //   this.form.submit();
  // });

  $('form#sort-form button.sort-criterion').click(function(event) {
    event.preventDefault();
    event.stopPropagation();
    var criterion = this.id.replace('sort_by_', '');
    $('input#sort').val(criterion);
    this.form.submit();
  });

  $('.filter').keypress(function (event) {
    // event.preventDefault();
    // event.stopPropagation();
    // this.val()
    // this.form.submit();

    if (event.keyCode == 13) {
      event.preventDefault();
      event.stopPropagation();
      // console.log($('#sort').val());
      // console.log(this.form);
      // this.form.submit();
    }
  });

  // $('form#sort-form').submit(function (event) {
  //   event.preventDefault();
  //   event.stopPropagation();
  //   var sort = $('#sort').val();
  //   var ok = confirm("Are you sure you want to submit? (sort = " + sort + ")");
  // });
});

function date_for_southwest_query(year, month, day) {
  if (day.length == 1) {
    day = "0" + day;
  }
  if (month.length == 1) {
    month = "0" + month;
  }
  return year + "-" + month + "-" + day;
}

function convert_to_time_format(time_string) {
  var hour = time_string.split(":")[0];
  hour = parseInt(hour);
  
  var minute_and_am_pm = time_string.split(":")[1];
  var minute = minute_and_am_pm.split(" ")[0];
  var am_pm = minute_and_am_pm.split(" ")[1];
  
  if (am_pm == "PM" && hour < 12) { hour += 12 };
  if (am_pm != "PM" && hour == 12) { hour = 0 };
  if (hour < 10) { hour = "0" + hour };

  return hour + ":" + minute;
}

function put_airports_in_input(select_element, input_field_id) {
  var selected_city = $(select_element).val();
  var airport_string = selected_city.match(/(?<=\().+(?=\))/)[0];
  airport_string = airport_string.replace(/\s/g, '');
  $(input_field_id).val(airport_string);
}
