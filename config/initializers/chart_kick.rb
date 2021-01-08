# Remove "Loading" text
Chartkick.options[:html] = <<-HTML
  <div id="%<id>s" style="height: %<height>s; width: %<width>s;">
  </div>
HTML
