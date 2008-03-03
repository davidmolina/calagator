# == Schema Information
# Schema version: 6
#
# Table name: events
#
#  id          :integer         not null, primary key
#  title       :string(255)
#  description :text
#  start_time  :datetime
#  end_time    :datetime
#  venue_id    :integer
#  url         :string(255)
#  source_id   :integer
#  created_at  :datetime
#  updated_at  :datetime
#

require 'vpim/icalendar'

# == Event
#
# A model representing a calendar event.
class Event < ActiveRecord::Base
  belongs_to :venue
  belongs_to :source
  validates_presence_of :title, :start_time

  #---[ Queries ]---------------------------------------------------------

  # Returns an Array of future Event instances.
  def self.find_all_future_events
    return find(:all, :conditions => [ 'start_time > ?', Date.today ], :order => 'start_time ASC')
  end

  #---[ Transformations ]-------------------------------------------------

  # Returns a new Event created from an AbstractEvent.
  def self.from_abstract_event(abstract_event)
    returning Event.new do |event|
      event.title        = abstract_event.title
      event.description  = abstract_event.description
      event.start_time   = abstract_event.start_time
      event.url          = abstract_event.url
      event.venue        = Venue.from_abstract_location(abstract_event.location) if abstract_event.location
    end
  end

  # Returns an hCalendar string representing this Event.
  def to_hcal
    <<-EOF
<div class="vevent">
<a class="url" href="#{url}">#{url}</a>
<span class="summary">#{title}</span>:
<abbr class="dtstart" title="#{start_time.to_s(:yyyymmdd)}">#{start_time.to_s(:long_date).gsub(/\b[0](\d)/, '\1')}</abbr>,
at the <span class="location">#{venue && venue.title}</span>
</div>
EOF
  end

  # Returns an iCalendar string representing this Event.
  def to_ical()
    self.class.to_ical(self)
  end

  # Return an iCalendar string representing an Array of Event instances.
  #
  # Arguments:
  # * :events - Event instance or array of them.
  #
  # Example:
  #   ics1 = Event.to_ical(myevent)
  #   ics2 = Event.to_ical(myevents)
  def self.to_ical(events, opts={})
    events = [events].flatten
    icalendar = Vpim::Icalendar.create2

    for event in events
      next if event.start_time.nil?
      icalendar.add_event do |c|
        c.dtstart       event.start_time
        c.dtend         event.end_time || event.start_time+1.hour
        c.summary       event.title || 'Untitled Event'
        c.description   event.description if event.description
        c.created       event.created_at if event.created_at
        c.lastmod       event.updated_at if event.updated_at
        c.url           event.url if event.url

        # TODO Figure out how to encode a venue. Remember that Vpim can't handle Vvenue itself and our parser had to go through many hoops to extract venues from the source data.
        #c.location     !event.venue.nil? ? event.venue.title : ''
      end
    end

    return icalendar.encode
  end
end
