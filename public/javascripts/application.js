$(function() {
  $('form.delete').submit(function(event) {
    event.preventDefault();
    event.stopPropagation();
    
    var ok = confirm('Are you sure you want to delete it? This cannot be undone.');

    if (ok) {
      this.submit();
    }
  });

  $('textarea#southwest_flight').change(function() {
    var text = $('#southwest_flight').val();

    $('#airline').val('Southwest');

    var flight_numbers = text.match(/\d+(?=\s\(opens popup\))/g);
    var flight_number = flight_numbers.join(", ");
    $('#number').val(flight_number);

    var departure_time_string = text.match(/\d+:\d+\s[AP]M/)[0];
    var departure_time_converted = convert_to_time_format(departure_time_string);
    $('#departure_time').val(departure_time_converted);
    
    var arrival_time_string = text.match(/\d+:\d+\s[AP]M/g)[1];
    var arrival_time_string_converted = convert_to_time_format(arrival_time_string);
    $('#arrival_time').val(arrival_time_string_converted);

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
});

function convert_to_time_format(time_string) {
  var hour = time_string.split(":")[0];
  hour = parseInt(hour);
  
  var minute_and_am_pm = time_string.split(":")[1];
  var minute = minute_and_am_pm.split(" ")[0];
  var am_pm = minute_and_am_pm.split(" ")[1];
  
  if (am_pm == "PM" && hour < 12) { hour += 12 };
  if (hour < 10) { hour = "0" + hour };

  return hour + ":" + minute;
}