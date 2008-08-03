class Feed
  attr_accessor :posts, :story_id
  
  def initialize(options = {})
    # decide where to get the feed
    if options[:story_id]
      url = "http://www.shacknews.com/laryn.x?story=#{options[:story_id]}"
    elsif options[:root_id]
      url = "http://www.shacknews.com/frame_laryn.x?root=#{options[:root_id]}&id=#{options[:root_id]}&mode=refresh"
    else
      url = 'http://www.shacknews.com/latestchatty.x'
    end
    
    # Get root post content
    parser = LibXML::XML::HTMLParser.new
    parser.string = bench('get feed') { open(url) }.read.gsub(/="\s*(.+?)\s*"/, '="\1"')
    page = parser.parse.root
    
    # Assign story id
    unless @story_id = options[:story_id]
      story = page.find_first('.//div[@class="story"]//h1//a')
      @story_id = story[:href].gsub('/onearticle.x/', '') if story
    end
    
    # Parse posts
    @posts = []
    page.find('.//div[@class="root"]').each do |xml|
      @posts << Post.new(xml, :parent => nil, :parse_children => options[:parse_children])
    end
  end
end