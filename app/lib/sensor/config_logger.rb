# Low-level formatting helpers for structured logging output
module Sensor::ConfigLogger
  SECTION_WIDTH = 78
  private_constant :SECTION_WIDTH

  SECTION_PADDING = 5
  private_constant :SECTION_PADDING

  SECTION_SPACING = 2 # spaces around title
  private_constant :SECTION_SPACING

  def log_section_header(title, char: '─', blank_after: true)
    log_blank
    left_padding = SECTION_PADDING
    right_padding =
      SECTION_WIDTH - left_padding - title.length - SECTION_SPACING
    log_line "#{char * left_padding} #{title} #{char * right_padding}"
    log_blank if blank_after
  end

  def log_section_footer(char: '─')
    log_line char * SECTION_WIDTH
  end

  def log_line(message)
    Rails.logger.info "  #{message}"
  end

  def log_blank
    Rails.logger.info ''
  end
end
