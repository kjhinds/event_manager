require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers(number)
  number.delete!('^0-9')
  if number.length == 10 || (number.length == 11 && number[0] == '1')
    number.chars.last(10).join.insert(6, '-').insert(3, '-')
  else
    'Invalid Number'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def convert_time(time)
  month, day, year, hour, minute = time.split(%r{[/ :]})
  Time.new(year, month, day, hour, minute)
end

def count_hours(time, hourly_distribution)
  hour = time.hour
  if hourly_distribution[hour].nil?
    hourly_distribution[hour] = 1
  else
    hourly_distribution[hour] += 1
  end
end

def count_weekdays(time, weekday_distribution)
  weekday = time.strftime('%A')
  if weekday_distribution[weekday].nil?
    weekday_distribution[weekday] = 1
  else
    weekday_distribution[weekday] += 1
  end
end

def most_popular(distribution)
  distribution.max_by { |_, v| v }[0]
end

puts 'EventManager Initialized'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
hourly_distribution = {}
weekday_distribution = {}

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  number = clean_phone_numbers(row[:homephone])
  time = convert_time(row[:regdate])
  count_hours(time, hourly_distribution)
  count_weekdays(time, weekday_distribution)

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  puts "Contact phone number: #{number}"
  save_thank_you_letter(id, form_letter)
end

puts "Most common hour registered: #{most_popular(hourly_distribution)}"
puts "Most common weekday registered: #{most_popular(weekday_distribution)}"
