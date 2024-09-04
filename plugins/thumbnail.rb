# Title: Thumbnail tag for Octopress (Jekyll).
# Author: rcmdnk (https://github.com/rcmdnk)
#
# Syntax {% thumbnail [class name(s)] [http[s]:/]/path/to/image [width [height]] [title text | "title text" ["alt text"]] %}
# Note: class name with a size or width + height are mandatory.
#
# Examples:
#
# * {% thumbnail /images/big_image.jpg 100 100 %}
#
# This makes /images/thumbnail/big_image_100_100.jpg with 100x100px size,
# and adds HTML:
#
#     <img src="/images/thumbnail/big_image_100_100.jpg" width="100" height="100">
#
# * {% thumbnail my-thumbnail /images/big_image.jpg %}
#
# You can use class name to define the size.
# To use the class, define width/height in your _config.yml like:
#
#     # Thumbnails
#     thumbnails:
#       - my-thumbnail
#     my-thumbnail-width: 200
#     my-thumbnail-height: 200
#
# Give class name to `thumbnails`, and define <class name>-width and <class name>-height.
#
# Then, the tag makes /images/thumbnail/big_image_200_200.jpg with 200x200px size,
# and adds HTML:
#
#     <img class="my-thumbnail" src="/images/thumbnail/big_image_200_200.jpg" width="200" height="200">
#
# * {% thumbnail my-thumbnail /images/big_image.jpg "This is a thumbnail"  "Thumbnail" %}
#
# You can add title/alt like img tag, too.
# This adds:
#
#     <img class="my-thumbnail" src="/images/thumbnail/big_image_200_200.jpg" width="200" height="200" title="This is a thumbnail" alt="Thumbnail">
#
#

module Jekyll

  class Thumbnail < Liquid::Tag
    @img = nil

    def initialize(tag_name, markup, tokens)
      attributes = ['class', 'src', 'width', 'height', 'title']

      if markup =~ /(?<class>\S.*\s+)?(?<src>(?:https?:\/\/|\S*\/|val:)\S+)(?:\s+(?<width>\d+))?(?:\s+(?<height>\d+))?(?<title>\s+.+)?/i
        @img = attributes.reduce({}) { |img, attr| img[attr] = $~[attr].strip if $~[attr]; img }
        if /(?:"|')(?<title>[^"']+)?(?:"|')\s+(?:"|')(?<alt>[^"']+)?(?:"|')/ =~ @img['title']
          @img['title']  = title
          @img['alt']    = alt
        else
          @img['title']  = @img['title'].gsub(/"/, '&#34;') if @img['title']
          @img['alt']    = @img['title'] if @img['title']
        end
        @img['class'] = @img['class'].gsub(/"/, '') if @img['class']
      end
      super
    end

    def render(context)
      site = context.registers[:site]
      vals = @img.clone
      if vals
        has_thumbnail_class = false
        if vals['class'] and site.config['thumbnails']
          site.config['thumbnails'].each do |t|
            if vals['class'].match(t)
              vals['class'] = vals['class'].gsub(t, t + '-img')
              has_thumbnail_class = true
              break
            end
          end
        end
        if (not vals.key?('width') or not vals.key?('height'))
          if not has_thumbnail_class
            raise 'Need width and height or thumbnail class for thumbnail!'
          end
          site.config['thumbnails'].each do |t|
            if vals['class'].match(t)
              vals['width'] = site.config[t + '-width'].to_s
              vals['height'] = site.config[t + '-height'].to_s
              break
            end
          end
        end
        vals['src'] = context[vals['src'].split(':')[1]] if vals['src'] =~ /^val:/
        if ! (vals['class'] and vals['class'].include?('noimgpath'))
          if site.config['imgpath'] and vals['src'] !~ /^(http|#{site.config['imgpath']})/
            vals['src'] = site.config['imgpath']+vals['src']
          end
        end
        local_file = self.get_local(vals['src'], site)
        if !vals['src'].start_with?('http') and File.extname(local_file) != '.gif' and File.exist?(local_file)
          thumbnail = File.dirname(vals['src']) + '/thumbnail/' + File.basename(vals['src'], '.*') + '_' + vals['width'] + '_' + vals['height'] + File.extname(vals['src'])
          thumbnail_local = self.get_local(thumbnail, site)
          if not File.exist?(thumbnail_local)
            `mkdir -p #{File.dirname(thumbnail_local)}`
            size = `identify -format "%w %h" #{local_file}`.strip().split()
            w = size[0].to_f
            h = size[1].to_f
            if w > vals['width'].to_f and h > vals['height'].to_f
              if w/vals['width'].to_f > h/vals['height'].to_f
                `convert -strip -thumbnail 'x#{vals['height']}' -crop '#{vals['width']}x#{vals['height']}+0+0' #{local_file} #{thumbnail_local}`
              else
                `convert -strip -thumbnail '#{vals['width']}x' -crop '#{vals['width']}x#{vals['height']}+0+0' #{local_file} #{thumbnail_local}`
              end
            else
              `convert -strip -crop '#{vals['width']}x#{vals['height']}+0+0' #{local_file} #{thumbnail_local}`
            end
            site.static_files << Jekyll::StaticFile.new(site, site.source, File.dirname(thumbnail_local).sub(site.source, ''), File.basename(thumbnail))
          end
          vals['src'] = thumbnail
          vals['alt'] = File.basename(thumbnail, '.*')
        else
          vals['alt'] = File.basename(vals['src'], '.*')
        end
        "<img #{vals.collect {|k,v| "#{k}=\"#{v}\"" if v}.join(" ")}>"
      else
        "Error processing input, expected syntax: {% thumbnail [class name(s)] [http[s]:/]/path/to/image [width [height]] [title text | \"title text\" [\"alt text\"]] %}"
      end
    end

    def get_local(file, site)
      if site.config['baseurl']
        file = file.sub(site.config['baseurl'], '')
      end
      if site.config['url']
        file = file.sub(site.config['url'], '')
      end
      if site.config['root']
        file = file.sub(site.config['root'], '')
      end
      if file[0] == "/" or site.source == "/"
        file = site.source + file
      else
        file = site.source + "/" + file
      end
      file
    end
  end
end

Liquid::Template.register_tag('thumbnail', Jekyll::Thumbnail)
