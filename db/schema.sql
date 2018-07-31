CREATE TABLE airlines(
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE
);

INSERT INTO airlines (name) VALUES ('Southwest');

CREATE TABLE cities(
  id serial PRIMARY KEY,
  name text NOT NULL
);

CREATE TABLE airports(
  id serial PRIMARY KEY,
  name text NOT NULL,
  code char(3) NOT NULL UNIQUE,
  city_id integer NOT NULL REFERENCES cities (id),
  state char(2)
);

INSERT INTO cities (name)
  VALUES ('Seattle'),
  ('San Francisco Bay Area'),
  ('Washington, DC');
INSERT INTO airports (name, state, code, city_id) VALUES ('Seattle/Tacoma', 'WA', 'SEA', 1);
INSERT INTO airports (name, state, code, city_id) VALUES ('Oakland', 'CA', 'OAK', 2);
INSERT INTO airports (name, state, code, city_id) VALUES ('San Francisco', 'CA', 'SFO', 2);
INSERT INTO airports (name, state, code, city_id) VALUES ('San Jose', 'CA', 'SJC', 2);
INSERT INTO airports (name, state, code, city_id) VALUES ('Baltimore/Washington', 'MD', 'BWI', 3);
INSERT INTO airports (name, state, code, city_id) VALUES ('Washington (Dulles)', 'VA', 'IAD', 3);
INSERT INTO airports (name, state, code, city_id) VALUES ('Washington (Reagan National)', 'DC', 'DCA', 3);

CREATE TABLE flights(
  id serial PRIMARY KEY,
  date date NOT NULL,
  airline_id integer NOT NULL REFERENCES airlines (id) ON DELETE CASCADE,
  flight_number text NOT NULL,
  origin char(3) NOT NULL REFERENCES airports (code) ON DELETE CASCADE,
  destination char(3) NOT NULL REFERENCES airports (code) ON DELETE CASCADE,
  departure_time timestamp without time zone NOT NULL,
  arrival_time timestamp without time zone NOT NULL,
  routing text NOT NULL,
  travel_time text NOT NULL,
  price numeric(6,2) NOT NULL,
  next_day_arrival boolean NOT NULL DEFAULT false,
  UNIQUE (airline_id, flight_number)
);
