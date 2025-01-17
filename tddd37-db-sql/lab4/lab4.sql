
DROP TABLE IF EXISTS contact CASCADE;
DROP TABLE IF EXISTS has_reserved CASCADE;
DROP TABLE IF EXISTS has_booked CASCADE;
DROP TABLE IF EXISTS ticket CASCADE;
DROP TABLE IF EXISTS booking CASCADE;

DROP TABLE IF EXISTS reservation CASCADE;
DROP TABLE IF EXISTS flight CASCADE;
DROP TABLE IF EXISTS credit_card CASCADE;
DROP TABLE IF EXISTS passenger CASCADE;

DROP TABLE IF EXISTS weekly_schedule CASCADE;
DROP TABLE IF EXISTS route CASCADE;
DROP TABLE IF EXISTS airport CASCADE;
DROP TABLE IF EXISTS weekday CASCADE;
DROP TABLE IF EXISTS year CASCADE;


create table year (
    year INTEGER,
    profit_factor DOUBLE,

    constraint pk_year primary key (year)
);

create table weekday (
    weekday VARCHAR(10),
    year INTEGER,
    weekday_factor DOUBLE,

    constraint pk_weekday primary key (weekday, year),
    constraint fk_year foreign key (year) references year(year) on delete cascade
);

create table airport (
    code VARCHAR(3),
    name VARCHAR(30),
    country VARCHAR(30),
    city VARCHAR(30),

    constraint pk_airport primary key (code)
);

create table route (
    departure VARCHAR(3),
    arrival VARCHAR(3),
    year INTEGER,
    routeprice DOUBLE,

    constraint pk_route primary key (departure, arrival, year),
    constraint fk_departure foreign key (departure) references airport(code) on delete cascade,
    constraint fk_arrival foreign key (arrival) references airport(code) on delete cascade
);

create table weekly_schedule (
    id INTEGER AUTO_INCREMENT,
    departure_time TIME,
    route_departure VARCHAR(3),
    route_arrival VARCHAR(3),
    weekday VARCHAR(10),
    year INTEGER,

    constraint pk_weekly_schedule primary key (id),
    constraint fk_route foreign key (route_departure, route_arrival, year) references route(departure, arrival, year) on delete cascade,
    constraint fk_weekday foreign key (weekday, year) references weekday(weekday, year) on delete cascade
);


create table flight (
    flight_number INTEGER AUTO_INCREMENT,
    weekly_schedule_id INTEGER,
    week INTEGER,

    constraint pk_flight primary key (flight_number),
    constraint fk_flight_weekly_schedule_id foreign key (weekly_schedule_id) references weekly_schedule(id) on delete cascade
);


create table credit_card (
    card_number BIGINT,
    holder VARCHAR(30),

    constraint pk_credit_card primary key (card_number)
);

create table reservation (
    reservation_number INTEGER,
    flight_number INTEGER,
    seats_reserved INTEGER,

    constraint pk_reservation primary key (reservation_number),
    constraint fk_reservation_flight_number foreign key (flight_number) references flight(flight_number) on delete cascade
);

create table booking (
    reservation_number INTEGER,
    price DOUBLE,
    credit_card_number BIGINT,

    constraint pk_booking primary key (reservation_number),
    constraint fk_booking_reservation_number foreign key (reservation_number) references reservation(reservation_number) on delete cascade,
    constraint fk_booking_credit_card_number foreign key (credit_card_number) references credit_card(card_number) on delete cascade
);

create table passenger (
    passport_number INTEGER,
    name VARCHAR(30),

    constraint pk_passenger primary key (passport_number)
);

create table contact (
    reservation_number INTEGER,
    passport_number INTEGER,
    phone_number BIGINT,
    email VARCHAR(30),

    constraint pk_contact primary key (reservation_number),
    constraint fk_contact_reservation_number foreign key (reservation_number) references reservation(reservation_number) on delete cascade,
    constraint fk_contact_passport_number foreign key (passport_number) references passenger(passport_number) on delete cascade
);

create table ticket (
    ticket_number INTEGER,
    passport_number INTEGER,
    booking_number INTEGER,

    constraint pk_ticket primary key (ticket_number),
    constraint fk_ticket_booking_number foreign key (booking_number) references booking(reservation_number) on delete cascade,
    constraint fk_ticket_passport_number foreign key (passport_number) references passenger(passport_number) on delete cascade
);

create table has_reserved (
    passport_number INTEGER,
    reservation_number INTEGER,

    constraint pk_has_reserved primary key (passport_number, reservation_number),
    constraint fk_has_reserved_reservation_number foreign key (reservation_number) references reservation(reservation_number) on delete cascade,
    constraint fk_has_reserved_passport_number foreign key (passport_number) references passenger(passport_number) on delete cascade
);


create table has_booked (
    passport_number INTEGER,
    booking_number INTEGER,

    constraint pk_has_booked primary key (passport_number, booking_number),
    constraint fk_has_booked_booking_number foreign key (booking_number) references booking(reservation_number) on delete cascade,
    constraint fk_has_booked_passport_number foreign key (passport_number) references passenger(passport_number) on delete cascade
);


drop procedure if exists addYear;
delimiter //
CREATE PROCEDURE addYear(in year integer, in factor double)
begin
	insert into year(year, profit_factor) values (year, factor);
end //
delimiter ;

drop procedure if exists addDay;
delimiter //
CREATE PROCEDURE addDay(in year integer, in day varchar(10), in factor double)
begin
	insert into weekday(weekday, year, weekday_factor) values (day, year, factor);
end //
delimiter ;

drop procedure if exists addDestination;
delimiter //
CREATE PROCEDURE addDestination(in airport_code varchar(3), in name varchar(30), in country varchar(30))
begin
	insert into airport(code, name, country) values (airport_code, name, country);
end //
delimiter ;

drop procedure if exists addRoute;
delimiter //
CREATE PROCEDURE addRoute(in departure_airport_code varchar(3), in arrival_airport_code varchar(3), in year integer, in routeprice double)
begin
	insert into route(departure, arrival, year, routeprice) values (departure_airport_code, arrival_airport_code, year, routeprice);
end //
delimiter ;

drop procedure if exists addFlight;
delimiter //
CREATE PROCEDURE addFlight(
  in departure_airport_code varchar(3),
  in arrival_airport_code varchar(3),
  in year integer,
  in day varchar(10),
  in departure_time time)
begin
  declare weekly_schedule_id integer;
  declare week_number integer default 1;
	insert into weekly_schedule(departure_time, route_departure, route_arrival, weekday, year)
      values (departure_time, departure_airport_code, arrival_airport_code, day, year);
  set weekly_schedule_id = last_insert_id();
  while week_number <= 52 do
    insert into flight(weekly_schedule_id, week) values (weekly_schedule_id, week_number);
    set week_number = week_number + 1;
  end while;
end //
delimiter ;

drop function if exists calculateFreeSeats;
delimiter //
create function calculateFreeSeats(flight_number integer)
  returns integer
begin
	declare free_seats integer default 40;
  declare booked_seats integer default 0;

  select sum(seats_booked) into booked_seats from
    (select reservation.flight_number, reservation.seats_reserved as seats_booked from booking
      inner join reservation on booking.reservation_number = reservation.reservation_number) as seats_booked_on_flight_number
    where seats_booked_on_flight_number.flight_number = flight_number;

  if booked_seats is NULL then
    return 40;
  end if;
  set free_seats = free_seats - booked_seats;
  return free_seats;
end //
delimiter ;


drop function if exists calculatePrice;
delimiter //
create function calculatePrice(flight_number integer)
  returns double
begin
  declare total_price double;
  declare routeprice double;
  declare weekday_factor double;
  declare profit_factor double;
  declare booked_passengers integer;
  declare schedule_id integer;

  declare route_departure varchar(3);
  declare route_arrival varchar(3);
  declare weekday varchar(10);
  declare year integer;

  set booked_passengers = 40 - calculateFreeSeats(flight_number);

  select weekly_schedule_id into schedule_id from flight where flight.flight_number = flight_number;

  select weekly_schedule.route_departure, weekly_schedule.route_arrival, weekly_schedule.weekday, weekly_schedule.year
    into route_departure, route_arrival, weekday, year
    from weekly_schedule where weekly_schedule.id = schedule_id;

  select route.routeprice into routeprice from route where (route_departure, route_arrival, year) = (route.departure, route.arrival, route.year);
  select weekday.weekday_factor into weekday_factor from weekday where (weekday, year) = (weekday.weekday, weekday.year);
  select year.profit_factor into profit_factor from year where year = year.year;

  set total_price = routeprice * weekday_factor * profit_factor * ((booked_passengers + 1) / 40);
  return total_price;
end //
delimiter ;


drop function if exists randrange;
delimiter //
create function randrange(start integer, stop integer)
  returns integer
begin
  return rand()*(stop-start)+start;
end //
delimiter ;


drop trigger if exists generate_tickets;
delimiter //
create trigger generate_tickets before insert on has_booked
for each row
begin
  declare ticket_nr int;
  declare ticket_exists int default 0;
  set ticket_nr = randrange(100000000, 999999999);
  select passport_number into ticket_exists from ticket where ticket_number = ticket_nr;
  while ticket_exists != 0 do
    set ticket_nr = randrange(100000000, 999999999);
    select ticket_number into ticket_exists from ticket where ticket_number = ticket_nr;
  end while;
  insert into ticket(ticket_number, passport_number, booking_number) values (ticket_nr, new.passport_number, new.booking_number);
end //
delimiter ;


drop procedure if exists addReservation;
delimiter //
CREATE PROCEDURE addReservation(
  in departure_airport_code varchar(3),
  in arrival_airport_code varchar(3),
  in year integer,
  in week integer,
  in day varchar(10),
  in time_ time,
  in number_of_passengers integer,
  out output_reservation_nr integer)
begin
  declare flight_number integer;
  declare weekly_schedule_id integer;
  declare free_seats integer default 0;
  declare reservation_nr integer;
  declare reservation_exists integer;
  select id into weekly_schedule_id from weekly_schedule where
    (departure_time, route_departure, route_arrival, weekday, weekly_schedule.year) =
    (time_, departure_airport_code, arrival_airport_code, day, year);
  if weekly_schedule_id is NULL then
    select "There exist no flight for the given route, date and time" as "Message";
  else
    select flight.flight_number into flight_number from flight where
      (flight.weekly_schedule_id, flight.week) = (weekly_schedule_id, week);
    set free_seats = calculateFreeSeats(flight_number);
    if free_seats < number_of_passengers then
      select "There are not enough seats available on the chosen flight" as "Message";
      set output_reservation_nr = NULL;
    else
      set reservation_nr = randrange(100000000, 999999999);
      select count(*) into reservation_exists from reservation where reservation_number = reservation_nr;
      while reservation_exists do
        set reservation_nr = randrange(100000000, 999999999);
        select count(*) into reservation_exists from reservation where reservation_number = reservation_nr;
      end while;
      insert into reservation(reservation.reservation_number, reservation.flight_number, reservation.seats_reserved)
         values (reservation_nr, flight_number, 0);
      set output_reservation_nr = reservation_nr;
    end if;
  end if;
end //
delimiter ;


drop procedure if exists addPassenger;
delimiter //
CREATE PROCEDURE addPassenger(
  in reservation_nr integer,
  in passport_number integer,
  in name varchar(30))
begin
  declare res_nr integer;
  declare pass_nr integer;
  declare booking_exists integer;
  select reservation_number into res_nr from reservation where reservation_number = reservation_nr;
  if res_nr is NULL then
    select "The given reservation number does not exist" as "Message";
  else
    select count(*) into booking_exists from booking where booking.reservation_number = reservation_nr;
    if booking_exists then
      select "The booking has already been payed and no futher passengers can be added" as "Message";
    else
      select passenger.passport_number into pass_nr from passenger where passenger.passport_number = passport_number;
      if pass_nr is NULL then
        insert into passenger values (passport_number, name) on duplicate key update passenger.name = name;
      end if;
      insert into has_reserved values (passport_number, reservation_nr);
      update reservation set seats_reserved = seats_reserved + 1 where reservation_number = reservation_nr;
    end if;
  end if;
end //
delimiter ;

drop procedure if exists addContact;
delimiter //
CREATE PROCEDURE addContact(
  in reservation_nr integer,
  in passport_number integer,
  in email varchar(30),
  in phone bigint)
begin
  declare res_nr integer;
  declare pass_nr integer;
  select reservation_number into res_nr from reservation where reservation_number = reservation_nr;
  if res_nr is NULL then
    select "The given reservation number does not exist" as "Message";
  else
    select has_reserved.passport_number into pass_nr from has_reserved
      where (has_reserved.reservation_number, has_reserved.passport_number) = (reservation_nr, passport_number);
    if pass_nr is NULL then
      select "The person is not a passenger of the reservation" as "Message";
    else
      insert into contact values (reservation_nr, passport_number, phone, email)
        on duplicate key update contact.passport_number = passport_number, contact.phone_number = phone, contact.email = email;
    end if;
  end if;
end //
delimiter ;


drop procedure if exists addPayment;
delimiter //
CREATE PROCEDURE addPayment(
  in reservation_nr integer,
  in cardholder_name varchar(30),
  in credit_card_number bigint)
begin
  declare res_nr integer;
  declare contact_pass_nr integer;
  declare booking_exists integer;
  declare price double;
  declare flight_nr integer;
  declare nr_of_passengers integer;
  select reservation_number into res_nr from reservation where reservation_number = reservation_nr;
  if res_nr is NULL then
    select "The given reservation number does not exist" as "Message";
  else
    select passport_number into contact_pass_nr from contact where contact.reservation_number = reservation_nr;
    if contact_pass_nr is NULL then
      select "The reservation has no contact yet" as "Message";
    else
      select count(*) into booking_exists from booking where booking.reservation_number = reservation_nr;
      if booking_exists then
        select "Reservation already paid for" as "Message";
      else
        select flight_number, seats_reserved into flight_nr, nr_of_passengers
          from reservation where reservation.reservation_number = reservation_nr;
        if calculateFreeSeats(flight_nr) < nr_of_passengers then
          select "There are not enough seats available on the flight anymore, deleting reservation" as "Message";
          delete from reservation where reservation.reservation_number = reservation_nr;
        else
          set price = nr_of_passengers * calculatePrice(flight_nr);
          insert into credit_card values (credit_card_number, cardholder_name)
            on duplicate key update credit_card.holder = cardholder_name;
          insert into booking values (reservation_nr, price, credit_card_number);
          insert into has_booked (has_booked.booking_number, has_booked.passport_number)
              (select has_reserved.reservation_number, has_reserved.passport_number
                from has_reserved where has_reserved.reservation_number = reservation_nr);
        end if;
      end if;
    end if;
  end if;
end //
delimiter ;

drop view if exists allFlights;
create view allFlights as
  (select
    (select name from airport where code = route_departure) as departure_city_name,
    (select name from airport where code = route_arrival) as destination_city_name,
    departure_time,
    weekday as departure_day,
    week as departure_week,
    year as departure_year,
    calculateFreeSeats(flight_number) as nr_of_free_seats,
    calculatePrice(flight_number) as current_price_per_seat
  from flight inner join weekly_schedule on flight.weekly_schedule_id = weekly_schedule.id);


#source tests/Question3.sql;
#source tests/Question6.sql;



/*
Question 8
a) How can you protect the credit card information in the database from hackers?
Answer:
Store credit_card_number as a hashed value instead of the actual number.
This would mean that payment needs to be handled before or in addPayment as we
can't get the credit_card_number after we hashed it so this might come with some complications.

We could also encrypt the credit_card_number but this relatively unsafe as all you need
to do is find the key and its like if all info was stored in plain text.

But the best way to go is to use an external payment service as to not deal with the problem yourself.


b)
Give three advantages of using stored procedures in the database (and thereby execute them on the server)
instead of writing the same functions in the front-end of the system (in for example java-script on a web-page)?
Answer:
* We separate the database from the front-end so that the database structure can be changed
without changing the front-end implementation.

* If the database is used by multiple front-ends then it removes duplicate code
that would be needed if it was handled at the front-end.

* Reduces the amount of data that is transferred and therefore reducing the
overall communication cost.


*/

/*
Question 9
a) In session A, add a new reservation.
Answer: Done

b)Is this reservation visible in session B? Why? Why not?
Answer:
It is not visible as the transaction has not been commited yet so not change has been made to the database

c)What happens if you try to modify the reservation from A in B?
Explain what happens and why this happens and how this relates to the concept of isolation of transactions.
Answer:
It is treated as if the reservation doesn't exists as from B's perspective it doesn't.
This relates to the concept of isolation as isolations means that this transaction does not
affect the outcome of other transactions.
*/

/*
Question 10
a) Did overbooking occur when the scripts were executed? If so, why? If not,
why not?
Answer:
An overbooking did not occur when the scripts were executed.

b) Can an overbooking theoretically occur? If an overbooking is possible, in what
order must the lines of code in your procedures/functions be executed.
Answer:
An overbooking can theoretically occur if the second calculateFreeSeats call
is done before we insert into booking.


c) Try to make the theoretical case occur in reality by simulating that multiple
sessions call the procedure at the same time. To specify the order in which the
lines of code are executed use the MySQL query SELECT sleep(5); which
makes the session sleep for 5 seconds. Note that it is not always possible to
make the theoretical case occur, if not, motivate why
Answer:
With running the script runMultipleTests.sh we were able to make
the theoretical case occur.


d) Modify the testscripts so that overbookings are no longer possible using
(some of) the commands START TRANSACTION, COMMIT, LOCK TABLES, UNLOCK
TABLES, ROLLBACK, SAVEPOINT, and SELECT?FOR UPDATE. Motivate why your
solution solves the issue, and test that this also is the case using the sleep
implemented in 10c. Note that it is not ok that one of the sessions ends up in a
deadlock scenario. Also, try to hold locks on the common resources for as
short time as possible to allow multiple sessions to be active at the same time.

Note that depending on how you have implemented the project it might be very
hard to block the overbooking due to how transactions and locks are
implemented in MySQL. If you have a good idea of how it should be solved but
are stuck on getting the queries right, talk to your lab-assistant and he or she
might help you get it right or allow you to hand in the exercise with
pseudocode and a theoretical explanation.
Answer:

lock tables
  booking write, reservation write, credit_card write, has_booked write,
  contact read, year read, flight read, weekday read, route read, weekly_schedule read, has_reserved read;
CALL addPayment (@a, "Sauron", 7878787878);
unlock tables;

look in tests/Question10MakeBooking.sql for full script.

This works because we lock booking so that no-one else can read from it, therefore
the other sessions will have to wait with calculateFreeSeats as it uses booking to calculate them.
The other locks are just there because of how mySQL locks work, we need to add locks to all
tables that are used in the stored procedure even if the locks themselves don't protect against anything.

*/


/*
Identify one case where a secondary index would be useful. Design the index, describe and motivate your design.

We feel like a secondary index might be useful in the case of the flight table.
This is because there are many flights and we sometimes search for a value
not based on the primary key. As we sometimes search for a flight based on
the superkey (weekly_schedule_id, week) we want to make this lookup faster.
We do this by making a seconday index were week points to the block were
there is a flight that week. We define the block size to be 8 just as an example
but it could be any number, less than 52 to have some effect. So everytime a new
row is added into flight we add a new row to the secondary index with the week
of and a pointer to the block this row was added into in flight. Because
week is a non-key we get multiple of the same week in our secondary index, we
solve this by using the dense index technique.


secondary index
week -> block
1 -> block 1
1 -> block 7
9 -> block 2
9 -> block 8
...

block_size = 8
week = 1, id = 1, flight  <----  (block 1)
week = 2, id = 1, flight
...
week = 8, id = 1, flight

week = 9, id = 1, flight  <----   (block 2)
week = 10, id = 1, flight
...
week = 16, id = 1, flight

...

week = 49, id = 1, flight  <----   (block 7)
week = 51, id = 1, flight
week = 52, id = 1, flight
week = 1, id = 2, flight
week = 2, id = 2, flight
week = 3, id = 2, flight
week = 4, id = 2, flight
week = 5, id = 2, flight

*/
