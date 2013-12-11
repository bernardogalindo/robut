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
    options = {location:"near=guadalajara,jalisco,mexico"}
    types =  Array(types).uniq if types
    options[:query] =  "#{CGI::escape(types[rand(types.length)])}"
    url = URI("https://api.foursquare.com/v2/venues/search?client_id=#{ENV['CLIENT_ID']}&"\
              "client_secret=#{ENV['CLIENT_SECRET']}&" \
              "v=#{Time.now.strftime('%Y%m%d')}&"\
              "#{options[:location]}&" \
              "categoryId=4d4b7105d754a06374d81259&" \
              "query=#{options[:query]}&intent=global&limit=20")
    req = Net::HTTP::Get.new(url.request_uri)
    res = Net::HTTP.start(url.host, url.port, :use_ssl => url.scheme == 'https') {|http|
      http.request(req)
    }
    jres = JSON.parse(res.body)
    @@list_place = jres["response"]["venues"].collect{|venue| venue["name"] } if res.code.to_i == 200
  end
  
  def get_venues=(options={})
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
              "query=#{options[:query]}&intent=global&limit=20")
    Robut::Plugin::Lunch.net_connect = url
  end
  
  def net_connect=(url)
    req = Net::HTTP::Get.new(url.request_uri)
    res = Net::HTTP.start(url.host, url.port, :use_ssl => url.scheme == 'https') {|http|
      http.request(req)
    }
    res
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
    elsif phrase =~ /lunch (.*) near (.*)/i && sent_to_me?(message)
      place = $1
      location = geocode_my_position $3
      location_string = location[0].to_s + "," + location[1].to_s
      options = {query: place, location: location_string}
      json_response = JSON.parse(self.get_venues=options )
      venues = json_response.body["response"]["venues"].collect{|venue| venue["name"] } if json_response.code.to_i == 200
      venues.each do |venue|
        new_place(venue)
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
    store["lunch_places"] ||= @@list_place
  end

  # Sets the list of lunch places to +v+
  def places=(v)
    store["lunch_places"] = v
  end
  
  def geocode_my_position=(q)
    q = CGI::escape(q)
    url = URI("http://maps.googleapis.com/maps/api/geocode/json?address=#{q}&sensor=true_or_false")
    res = self.net_connect(url)
    if res.code == 200
      json_response = JSON.parse(res.body)
      lat = json_response["results"]["geomety"]["location"]["lat"] 
      lng = json_response["results"]["geomety"]["location"]["lng"]
      [lat, lng]
    end
  end
    

end
