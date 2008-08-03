class Post
  attr_accessor :id, :author, :date, :preview, :body, :children, :parent, :category
  
  def self.create(body, options)
    username  = options[:username]
    password  = options[:password]
    parent_id = options[:parent_id]
    story_id  = options[:story_id]
    
    # get the right cookie
    cookie = login_cookie(username, password)
    
    # Abort if authentication failed
    return :not_authorized if cookie == :not_authorized
    
    # Setup the request
    url = URI.parse('http://www.shacknews.com/post_laryn.x')
    request = Net::HTTP::Post.new(url.path)
    request['Cookie'] = cookie
    request.set_form_data :parent => parent_id,
                          :group  => story_id,
                          :dopost => 'dopost',
                          :body   => body
  
    Net::HTTP.new(url.host, url.port).start { |http| http.request(request) }
  end
  
  # Return a cookie that can be used with a post
  def self.login_cookie(username, password)
    # Post the login
    response = Net::HTTP.post_form(URI.parse('http://www.shacknews.com/login_laryn.x'), {
      :username => username,
      :password => password,
      :type     => 'login'
    })
    
    if cookie = response.to_hash['set-cookie'].find { |cookie| cookie =~ /^pass=/ }
      # Get the encrypted password form the response cookies
      encrypted_password = response.to_hash['set-cookie'].find { |cookie| cookie =~ /^pass=/ }
      encrypted_password = encrypted_password.match(/pass=([a-f0-9]+?);/)[1]
    
      # Create a cookie string to send back
      "user=#{username}; pass=#{encrypted_password}"
    else
      :not_authorized
    end
  end
  
  def initialize(xml, options = {})
    # setup an empty array for collecting child posts
    @children = []
  
    # Save the parent post
    @parent = options[:parent]
    
    # Find the id of this post.
    @id = (is_root?(xml) ? xml.find_first('.//li[@id]').attributes[:id] : xml.attributes[:id]).gsub('item_', '').to_i
    
    post_content_feed = options[:post_content_feed]
    if options[:parse_children]
      # Get the content for a thread.  This should only be done for the root post.
      # Get root post content
      post_content_feed ||= begin
        parser = LibXML::XML::HTMLParser.new
        parser.string = bench('get feed') { open("http://www.shacknews.com/frame_laryn.x?root=#{@id}") }.read
        parser.parse.root
      end
    end
    
    # Parse the main feed.
    
    # Root post
    if is_root?(xml)
      @author = xml.find_first('.//span[@class="author"]/a').content.strip
      @date   = xml.find_first('.//div[@class="postdate"]').content.strip
      @body   = xml.find_first('.//div[@class="postbody"]').to_s.inner_html.strip
      
      @preview = @body.gsub(/<.+?>/, '')[0..100]
      
      child_selector = './/div[@class="capcontainer"]/ul/li'
    
    # Child post
    else
      @author = xml.find_first('.//a[@class="oneline_user"]').content.strip
      @date   = post_content_feed.find_first("//div[@id='item_#{@id}']//div[@class='postdate']").content.strip
      @body   = post_content_feed.find_first(".//div[@id='item_#{@id}']//div[@class='postbody']").to_s.inner_html.strip
      @preview = xml.find_first('.//span[@class="oneline_body"]').to_s.inner_html.strip.gsub(/<.+?>/, '')
      
      child_selector = 'ul/li'
    end
    
    # Convert spoiler javascript to something simpler
    @body = @body.gsub("return doSpoiler( event )", "this.className = ''")
    
    if options[:parse_children]
      # Create child posts
      xml.find(child_selector).each do |child_post|
        @children << Post.new(child_post, :parent => self, :post_content_feed => post_content_feed, :parse_children => options[:parse_children])
      end
    end
  end
  
  private
    def is_root?(xml)
      xml.find_first('ul/li/div/div[@class="postbody"]')
    end

end