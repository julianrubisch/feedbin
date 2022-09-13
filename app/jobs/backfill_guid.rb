class BackfillGuid
  include Sidekiq::Worker
  include BatchJobs
  sidekiq_options queue: :worker_slow

  def perform(feed_id)
    @feed = Feed.find(feed_id)
    entries = Entry.where(feed: @feed).select(:id, :entry_id, :url, :title)
    data = entries.each_with_object({}) do |entry, hash|
      hash[entry.id] = guid(entry)
    end
    Entry.update_multiple(column: :guid, data: data)
  end

  def build
    enqueue_all(Feed, self.class)
  end

  def guid(entry)
    normalized = remove_protocol_and_host(uri: entry.entry_id) unless entry.entry_id.nil?
    normalized = build_id(normalized, entry)
    Digest::MD5.hexdigest(normalized)
  end

  def build_id(entry_id, entry)
    parts = []
    parts.push(@feed.feed_url)
    parts.push(entry_id)
    unless entry.entry_id
      parts.push(entry.url)
      parts.push(entry.title)
    end
    parts.compact.join
  end

  def remove_protocol_and_host(uri:)
    parsed = URI(uri)
    result = [parsed.userinfo, parsed.path, parsed.query, parsed.fragment].join
    result == "" ? uri : result
  rescue
    uri.gsub!("http:", "")
    uri.gsub!("https:", "")
    uri
  end
end
