# Where should we go to lunch today?
# encoding: UTF-8
require 'net/http'
require 'cgi'
require 'json'
class Robut::Plugin::Lunch
  include Robut::Plugin
 
  def self.default_places
    @@list_place
  end

  def self.default_places=(types)
    @@list_place = nil
    record = {}
    options = {location:"near=guadalajara,jalisco,mexico"}
    types =  Array(types).uniq if types
    options[:query] =  "#{CGI::escape(types[rand(types.length)])}"
    url = URI("https://api.foursquare.com/v2/venues/search?client_id=#{ENV['CLIENT_ID']}&"\
              "client_secret=#{ENV['CLIENT_SECRET']}&" \
              "v=#{Time.now.strftime('%Y%m%d')}&"\
              "#{options[:location]}&" \
              "categoryId=4d4b7105d754a06374d81259&" \
              "query=#{options[:query]}")
    req = Net::HTTP::Get.new(url.request_uri)
    res = Net::HTTP.start(url.host, url.port, :use_ssl => url.scheme == 'https') {|http|
      http.request(req)
    }
    jres = JSON.parse(res.body)
    if res.code.to_i == 200
      @@list_place = jres["response"]["venues"].collect do |venue|
        record[:name] = venue["name"]
        record[:contact] = venue["contact"]["formattedPhone"] if venue.has_key?("contact")
        if venue.has_key?("location") 
          record[:location] = venue["location"]["address"]  
          record[:location] += " " + venue["location"]["crossStreet"] if venue["location"]["crossStreet"]
        end
        record 
      end
    end
  end
  
  def get_venues(options={})
    options[:location] = "ll=#{options[:location]}" if options[:location]
    default_options = {location:"near=guadalajara,jalisco,mexico"}
    options = default_options.merge(options)
    types =  Array(options[:query]).uniq if options[:query]
    options[:query] =  "#{CGI::escape(types[rand(types.length)])}"
    url = URI("https://api.foursquare.com/v2/venues/search?client_id=#{ENV['CLIENT_ID']}&"\
              "client_secret=#{ENV['CLIENT_SECRET']}&" \
              "v=#{Time.now.strftime('%Y%m%d')}&"\
              "#{options[:location]}&" \
              "categoryId=4d4b7105d754a06374d81259&" \
              "query=#{options[:query]}")
    self.net_connect url
  end
  
  def net_connect(url)
    req = Net::HTTP::Get.new(url.request_uri)
    res = Net::HTTP.start(url.host, url.port, :use_ssl => url.scheme == 'https') {|http|
      http.request(req)
    }
  end
  
  def self.my_ip
    url = URI.parse('curlmyip.com')
    req = Net::HTTP::Get.new(url.path)
    ip = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
  end
  

  # Returns a description of how to use this plugin
  def usage
    [
      "lunch? / food? - #{nick} will suggest a place to go eat",
      "#{at_nick} lunch places - lists all the lunch places #{nick} knows about",
      "#{at_nick} new lunch place <place> - tells #{nick} about a new place to eat",
      "#{at_nick} remove lunch place <place> - tells #{nick} not to suggest <place> anymore",
      "#{at_nick} where is this place <place> - tells #{nick} to tell you where is the <place>",
      "#{at_nick} lunch <type> near <place> - tells #{nick} to find the <type> of food near to <place>"
    ]
  end

  # Replies with a random string selected from +places+.
  def handle(time, sender_nick, message)
    words = words(message)
    phrase = words.join(' ')
    # lunch?
    if phrase =~ /(lunch|food)\?/i
      if places.empty?
        reply "I don't know about any lunch places"
      else
        reply places[rand(places.length)] + "!"
      end
    # @robut lunch places
    elsif phrase == "lunch places" && sent_to_me?(message)
      if places.empty?
        reply "I don't know about any lunch places"
      else
        reply places.join(', ')
      end
    # @robut new lunch place Green Leaf
    elsif phrase =~ /new lunch place (.*)/i && sent_to_me?(message)
      place = $1
      new_place(place)
      reply "Ok, I'll add \"#{place}\" to the the list of lunch places"
    # @robut remove luynch place Green Leaf
    elsif phrase =~ /remove lunch place (.*)/i && sent_to_me?(message)
      place = $1
      remove_place(place)
      reply "I removed \"#{place}\" from the list of lunch places"
    elsif phrase =~ /where is this place (.*)/i && sent_to_me?(message)
      place = place_by_name $1
      if place
        reply place
      else
        reply "I don't know; what you talkin about; eat whereever you want!"
      end
    elsif phrase =~ /lunch (.*) near to (.*)/i && sent_to_me?(message)
      place = $1
      location = geocode_my_position $2
      location_string = location[0].to_s + "," + location[1].to_s
      options = {query: place, location: location_string}
      res = self.get_venues options
      json_response = JSON.parse( res.body )
      record = {}
      if res.code.to_i == 200
        venues = json_response["response"]["venues"].collect do |venue|
          record[:name] = venue["name"]
          record[:contact] = venue["contact"]["formattedPhone"] if venue.has_key?("contact")
          if venue.has_key?("location") 
            record[:location] = venue["location"]["address"]  
            record[:location] += " " + venue["location"]["crossStreet"] if venue["location"]["crossStreet"]
          end
          record
        end
        more_relevant = venues.first
        venues.each do |venue|
          new_place(venue)
        end
        reply "Ok, I'll add \"#{place}\" places to the the list of lunch places. I recommend you to go to \"#{more_relevant} \""
      else
        reply "I don't know about any lunch #{place} near to #{$2}"
      end
    end
  end

  # Stores +place+ as a new lunch place.
  def new_place(place)
    store["lunch_places"] ||= []
    store["lunch_places"] = (store["lunch_places"] + Array(place)).uniq
  end

  # Removes +place+ from the list of lunch places.
  def remove_place(place)
    store["lunch_places"] ||= []
    store["lunch_places"] = store["lunch_places"] - Array(place)
  end

  # Returns the list of lunch places we know about.
  def places
    store["lunch_places"] ||= []
    store["lunch_places"] = Array(store["lunch_places"] + @@list_place).uniq if @@list_place
    store["lunch_places"].map{|place| place[:name]}
  end
  
  def place_by_name name
    store["lunch_places"].select do |place|
      next unless place[:name] == name
      res = place[:location] if place[:location]
      res += ", " + place[:contact] if place[:contact]
      res
    end
  end

  # Sets the list of lunch places to +v+
  def places=(v)
    store["lunch_places"] = v
  end
  
  
  def geocode_my_position(q)
    q = CGI::escape(q)
    url = URI("http://maps.googleapis.com/maps/api/geocode/json?address=#{q}&sensor=true")
    res = self.net_connect url
    if res.code.to_i == 200
      json_response = JSON.parse(res.body)
      lat = json_response["results"].first["geometry"]["location"]["lat"] 
      lng = json_response["results"].first["geometry"]["location"]["lng"]
      [lat, lng]
    end
  end
    

end
