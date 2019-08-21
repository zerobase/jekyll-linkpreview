require "digest"
require "json"

require "metainspector"
require "jekyll-linkpreview/version"

module Jekyll
  module Linkpreview
    class OpenGraphProperties
      def get(url)
        og_properties = fetch(url)
        og_url = get_og_property(og_properties, 'og:url')
        domain = extract_domain(og_url)
        image_url = get_og_property(og_properties, 'og:image')
        {
          'title'       => get_og_property(og_properties, 'og:title'),
          'url'         => og_url,
          'image'       => convert_to_absolute_url(image_url, domain),
          'description' => get_og_property(og_properties, 'og:description'),
          'domain'      => domain
        }
      end

      private
      def get_og_property(properties, key)
        if !properties.key? key then
          return nil
        end
        properties[key][0]
      end

      private
      def fetch(url)
        MetaInspector.new(url).meta_tags['property']
      end

      private
      def convert_to_absolute_url(url, domain)
        if url.nil? then
          return nil
        end
        # root relative url
        if url[0] == '/' then
          return "//#{domain}#{url}"
        end
        url
      end

      private
      def extract_domain(url)
        if url.nil? then
          return nil
        end
        url.match(%r{(http|https)://([^/]+).*})[-1]
      end
    end

    class LinkpreviewTag < Liquid::Tag
      @@cache_dir = '_cache'

      def initialize(tag_name, markup, parse_context)
        super
        @markup = markup.rstrip()
        @og_properties = OpenGraphProperties.new
      end

      def render(context)
        url = get_url_from(context)
        properties = get_properties(url)
        title       = properties['title']
        image       = properties['image']
        description = properties['description']
        domain      = properties['domain']
        if title.nil? || image.nil? || description.nil? || domain.nil? then
          html = <<-EOS
<div class="jekyll-linkpreview-wrapper">
  <p><a href="#{url}" target="_blank">#{url}</a></p>
</div>
          EOS
          return html
        end
        html = <<-EOS
<div class="jekyll-linkpreview-wrapper">
  <p><a href="#{url}" target="_blank">#{url}</a></p>
  <div class="jekyll-linkpreview-wrapper-inner">
    <div class="jekyll-linkpreview-content">
      <div class="jekyll-linkpreview-image">
        <a href="#{url}" target="_blank">
          <img src="#{image}" />
        </a>
      </div>
      <div class="jekyll-linkpreview-body">
        <h2 class="jekyll-linkpreview-title">
          <a href="#{url}" target="_blank">#{title}</a>
        </h2>
        <div class="jekyll-linkpreview-description">#{description}</div>
      </div>
    </div>
    <div class="jekyll-linkpreview-footer">
      <a href="//#{domain}" target="_blank">#{domain}</a>
    </div>
  </div>
</div>
        EOS
        html
      end

      def get_properties(url)
        cache_filepath = "#{@@cache_dir}/%s.json" % Digest::MD5.hexdigest(url)
        if File.exist?(cache_filepath) then
          return load_cache_file(cache_filepath)
        end
        properties = @og_properties.get(url)
        if Dir.exists?(@@cache_dir) then
          save_cache_file(cache_filepath, properties)
        else
          # TODO: This message will be shown at all linkprevew tag
          warn "'#{@@cache_dir}' directory does not exist. Create it for caching."
        end
        properties
      end

      private
      def get_url_from(context)
        context.scopes[0].key?(@markup) ? context.scopes[0][@markup] : @markup
      end

      private
      def load_cache_file(filepath)
        JSON.parse(File.open(filepath).read)
      end

      protected
      def save_cache_file(filepath, properties)
        File.open(filepath, 'w').write(JSON.generate(properties))
      end
    end
  end
end

Liquid::Template.register_tag("linkpreview", Jekyll::Linkpreview::LinkpreviewTag)
