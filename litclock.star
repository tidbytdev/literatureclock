"""
Applet: Literature Clock Custom
Summary: Literary quotes for time
Description: Shows quotes from literature that mention the current time, updating each minute. Includes configurable colors, fonts (per element), and timezone using the tidbyt/literatureclock data source with dynamic caching and pre-fetching.
Author: TDevelop
"""

# Load necessary modules
load("render.star", "render")
load("time.star", "time")
load("http.star", "http")
load("encoding/json.star", "json")
load("schema.star", "schema")
load("cache.star", "cache") # Keep cache loaded, good practice

# Constants
# NOTE: Assumes the hourly files are now in a location accessible via this base URL
# You MUST update this URL to point to where your *clean* (no overlap) hourly files are hosted.
BASE_URL = "https://raw.githubusercontent.com/tidbytdev/literatureclock/main/hours/" # <<< EXAMPLE - ADJUST THIS

# Schema definition for configuration (Corrected: No Headers, Grouped Names)
def get_schema():
    # Define timezone options for the dropdown
    TIMEZONE_OPTIONS = [
        schema.Option(display = "Device Timezone", value = "$tz"),
        schema.Option(display = "UTC", value = "UTC"),
        schema.Option(display = "New York (ET)", value = "America/New_York"),
        schema.Option(display = "Chicago (CT)", value = "America/Chicago"),
        schema.Option(display = "Denver (MT)", value = "America/Denver"),
        schema.Option(display = "Los Angeles (PT)", value = "America/Los_Angeles"),
        schema.Option(display = "Anchorage (AKT)", value = "America/Anchorage"),
        schema.Option(display = "Honolulu (HST)", value = "Pacific/Honolulu"),
        schema.Option(display = "London (GMT/BST)", value = "Europe/London"),
        schema.Option(display = "Berlin (CET/CEST)", value = "Europe/Berlin"),
        schema.Option(display = "Athens (EET/EEST)", value = "Europe/Athens"),
        schema.Option(display = "Moscow (MSK)", value = "Europe/Moscow"),
        schema.Option(display = "India (IST)", value = "Asia/Kolkata"),
        schema.Option(display = "Shanghai (CST)", value = "Asia/Shanghai"),
        schema.Option(display = "Tokyo (JST)", value = "Asia/Tokyo"),
        schema.Option(display = "Sydney (AET)", value = "Australia/Sydney"),
        schema.Option(display = "Perth (AWST)", value = "Australia/Perth"),
        schema.Option(display = "Mexico City (CST)", value = "America/Mexico_City"),
        schema.Option(display = "Sao Paulo (-3)", value = "America/Sao_Paulo"),
    ]

    # Define font options
    FONT_OPTIONS = [
        schema.Option(display="Tom Thumb (3x5)", value="tb"),
        schema.Option(display="CG Pixel (3x5)", value="cg3x5"),
        schema.Option(display="CG Pixel (4x5)", value="cg4x5"),
        schema.Option(display="5x8", value="5x8"),
        schema.Option(display="Dina", value="Dina"),
        schema.Option(display="Pixelade", value="Pixelade"),
        schema.Option(display="6x10", value="6x10"),
        schema.Option(display="6x13", value="6x13"),
        schema.Option(display="10x20", value="10x20"),
    ]
    FONT_SIZE_OPTIONS_DESC = "Size (small, medium, large) - Note: May not affect all fonts."

    return schema.Schema(
        version = "1",
        fields = [
            # --- General Settings ---
            schema.Color( id = "bg_color", name = "Background Color", desc = "Background color for the applet.", icon = "palette", default = "#000000"),
            schema.Dropdown( id = "user_timezone", name = "Timezone", desc = "Select the timezone for the clock.", icon = "locationDot", options = TIMEZONE_OPTIONS, default = TIMEZONE_OPTIONS[0].value),

            # --- Quote Context Text Settings ---
            schema.Color( id = "quote_color", name = "Quote Color", desc = "Color for text BEFORE and AFTER the time.", icon = "palette", default = "#FFFFFF"),
            schema.Dropdown( id = "quote_before_font", name = "Quote Before Font", desc = "Font for text BEFORE time.", icon = "font", options = FONT_OPTIONS, default = "tb"),
            schema.Text( id = "quote_before_font_size", name = "Quote Before Size", desc = FONT_SIZE_OPTIONS_DESC, icon = "textHeight", default = "small"),
            schema.Dropdown( id = "quote_after_font", name = "Quote After Font", desc = "Font for text AFTER time.", icon = "font", options = FONT_OPTIONS, default = "tb"),
            schema.Text( id = "quote_after_font_size", name = "Quote After Size", desc = FONT_SIZE_OPTIONS_DESC, icon = "textHeight", default = "small"),

            # --- Time Reference Text Settings ---
            schema.Color( id = "time_ref_color", name = "Time Reference Color", desc = "Color for the time text itself.", icon = "palette", default = "#FFDB5B"),
            schema.Dropdown( id = "time_ref_font", name = "Time Reference Font", desc = "Font for the time text itself.", icon = "font", options = FONT_OPTIONS, default = "6x13"),
            schema.Text( id = "time_ref_font_size", name = "Time Reference Size", desc = FONT_SIZE_OPTIONS_DESC, icon = "textHeight", default = "large"),

            # --- Book Title Text Settings ---
            schema.Color( id = "title_color", name = "Book Title Color", desc = "Color for the book title.", icon = "palette", default = "#8AFFD4"),
            schema.Dropdown( id = "title_font", name = "Book Title Font", desc = "Font for the book title.", icon = "font", options = FONT_OPTIONS, default = "tb"),
            schema.Text( id = "title_font_size", name = "Book Title Size", desc = FONT_SIZE_OPTIONS_DESC, icon = "textHeight", default = "small"),

            # --- Author Name Text Settings ---
            schema.Color( id = "author_color", name = "Author Name Color", desc = "Color for the author's name.", icon = "palette", default = "#95FF8A"),
            schema.Dropdown( id = "author_font", name = "Author Name Font", desc = "Font for the author's name.", icon = "font", options = FONT_OPTIONS, default = "tb"),
            schema.Text( id = "author_font_size", name = "Author Name Size", desc = FONT_SIZE_OPTIONS_DESC, icon = "textHeight", default = "small"),
        ]
    )

# Helper Functions
def get_font_details(font, font_size):
    """Determine exact font based on selection"""
    valid_fonts = ["tb", "6x13", "Dina", "Pixelade", "5x8", "cg3x5", "cg4x5", "6x10", "10x20"]
    if font not in valid_fonts: font = "tb"
    if font_size not in ["small", "medium", "large"]: font_size = "small"
    font_map = { ("tb", "small"): "tom-thumb", ("tb", "medium"): "tom-thumb", ("tb", "large"): "tom-thumb", ("6x13", "small"): "6x13", ("6x13", "medium"): "6x13", ("6x13", "large"): "6x13", ("Dina", "small"): "Dina_r400-8", ("Dina", "medium"): "Dina_r400-8", ("Dina", "large"): "Dina_r400-8", ("Pixelade", "small"): "Pixelade", ("Pixelade", "medium"): "Pixelade", ("Pixelade", "large"): "Pixelade", ("5x8", "small"): "5x8", ("5x8", "medium"): "5x8", ("5x8", "large"): "5x8", ("cg3x5", "small"): "CG-pixel-3x5-mono", ("cg3x5", "medium"): "CG-pixel-3x5-mono", ("cg3x5", "large"): "CG-pixel-3x5-mono", ("cg4x5", "small"): "CG-pixel-4x5-mono", ("cg4x5", "medium"): "CG-pixel-4x5-mono", ("cg4x5", "large"): "CG-pixel-4x5-mono", ("6x10", "small"): "6x10", ("6x10", "medium"): "6x10", ("6x10", "large"): "6x10", ("10x20", "small"): "10x20", ("10x20", "medium"): "10x20", ("10x20", "large"): "10x20", }
    return font_map.get((font, font_size), "tom-thumb")

# fetch_hour_data uses Dynamic TTL
def fetch_hour_data(hour_str, now):
    """Fetches quote data for the given hour, caching until the next hour."""
    url = BASE_URL + hour_str + "_quotes.json"
    seconds_past_hour = now.minute * 60 + now.second
    seconds_remaining_in_hour = 3600 - seconds_past_hour
    ttl = max(1, seconds_remaining_in_hour + 10)
    response = http.get(url, ttl_seconds=ttl)
    if response.status_code != 200: print("Failed fetch: %s, Status: %d" % (url, response.status_code)); return None
    body = response.body()
    if not body: print("Empty response body for: %s" % url); return None
    data = json.decode(body)
    if data == None: fail("Failed to decode JSON for: %s" % url)
    return data

# CORRECTED get_quote_for_minute (uses type() and .second)
def get_quote_for_minute(hour_data, minute_str):
    """Selects a quote for the given minute from the provided hour_data."""
    if not hour_data or minute_str not in hour_data: return None
    quotes = hour_data.get(minute_str)
    if not quotes or type(quotes) != "list": return None
    quotes_count = len(quotes)
    if quotes_count == 0: return None
    idx = time.now().second % quotes_count
    return quotes[idx]

# prepare_quote_lines (Accepts specific fonts for title/author & replaces <br>)
def prepare_quote_lines(quote, quote_color, author_color, title_color, title_display_font, author_display_font):
    """Prepares quote data, cleans text, assigns fonts/colors to meta lines."""
    def replace_br(text):
        if not text: return ""
        text = text.replace("<br />", "\n").replace("<br/>", "\n").replace("<br>", "\n")
        return text.strip()
    left = replace_br(quote.get("left", "") or ""); bold = replace_br(quote.get("bold", "") or ""); right = replace_br(quote.get("right", "") or "")
    author = replace_br(quote.get("author", "") or ""); title = replace_br(quote.get("title", "") or "")
    main_quote_parts = {"left": left, "bold": bold, "right": right}
    meta_lines = []
    if (left or bold or right) and (title or author): meta_lines.append({"text": " ", "color": quote_color, "font": author_display_font, "align": "center"})
    if title: meta_lines.append({"text": title, "color": title_color, "align": "center", "font": title_display_font})
    if author: meta_lines.append({"text": author, "color": author_color, "align": "center", "font": author_display_font})
    return main_quote_parts, meta_lines

# Rendering Functions
# render_scrolling_quote (Uses intermediate vars, check formatting)
def render_scrolling_quote(
        quote,
        # Colors
        quote_color, time_ref_color, author_color, title_color, bg_color,
        # Fonts
        quote_before_font, time_ref_font, quote_after_font, title_font, author_font):
    """Renders prepared quote lines, using separate WrappedText & intermediate vars."""

    main_quote_parts, meta_lines = prepare_quote_lines(
        quote = quote, quote_color = quote_color, author_color = author_color,
        title_color = title_color, title_display_font = title_font, author_display_font = author_font,
    )
    has_left = bool(main_quote_parts["left"]); has_bold = bool(main_quote_parts["bold"]); has_right = bool(main_quote_parts["right"])
    has_main_quote = has_left or has_bold or has_right; has_meta = bool(meta_lines)
    if not has_main_quote and not has_meta: return render_error(quote_color, bg_color, quote_before_font)

    start_pos = 32; fixed_scroll_height = 32 * 5; end_pos = -(fixed_scroll_height); loop_end = end_pos - 1

    # --- Build Content Column (using intermediate variables) ---
    content_children = []
    if has_left:
        left_widget = render.WrappedText( content=main_quote_parts["left"], font=quote_before_font, color=quote_color, width=64, align="left" )
        content_children.append(left_widget)
    if has_bold:
        bold_widget = render.WrappedText( content=main_quote_parts["bold"], font=time_ref_font, color=time_ref_color, width=64, align="left" )
        content_children.append(bold_widget)
    if has_right:
        right_widget = render.WrappedText( content=main_quote_parts["right"], font=quote_after_font, color=quote_color, width=64, align="left" )
        content_children.append(right_widget)

    # Add the meta lines
    for line_info in meta_lines: # Error occurred around here previously
        meta_widget = render.WrappedText( content=line_info["text"], font=line_info["font"], color=line_info["color"], width=64, align=line_info["align"], linespacing=1 )
        content_children.append(meta_widget)

    # Create the main Column
    text_column = render.Column(
        children=content_children,
        main_align="start",
        cross_align="center",
    )
    # --- End Build Content Column ---

    # --- Create Animation Frames ---
    animation_frames = []; # Semicolon for compactness, ensure parser handles it
    for i in range(start_pos, loop_end, -1):
        animation_frames.append( render.Padding( pad=(0, i, 0, 0), child=text_column ) )
    # --- End Create Animation Frames ---

    # --- Final Rendering ---
    return render.Root(
        delay=75, show_full_animation=True, max_age=120,
        child = render.Box( width=64, height=32, color=bg_color, child=render.Animation(children=animation_frames) )
    )
    # --- End Final Rendering ---

# Updated render_error (Accepts a font)
def render_error(quote_color, bg_color, font):
    """Renders an error message using the provided font"""
    return render.Root( child = render.Box( color=bg_color, child = render.Column( main_align = "center", cross_align = "center", children = [ render.Text( content = "No quote", font = font, color = quote_color, align = "center", ), render.Text( content = "for time", font = font, color = quote_color, align = "center", ), ], ) ) )

# Updated main function (Reads new schema IDs, passes new params, correct time add)
def main(config):
    # Get config values using NEW IDs
    quote_color = config.get("quote_color", "#FFFFFF"); time_ref_color = config.get("time_ref_color", "#FFDB5B")
    author_color = config.get("author_color", "#95FF8A"); title_color = config.get("title_color", "#8AFFD4")
    bg_color = config.get("bg_color", "#000000")
    quote_before_font_name = config.get("quote_before_font", "tb"); quote_before_font_size = config.get("quote_before_font_size", "small")
    time_ref_font_name = config.get("time_ref_font", "6x13"); time_ref_font_size = config.get("time_ref_font_size", "large")
    quote_after_font_name = config.get("quote_after_font", "tb"); quote_after_font_size = config.get("quote_after_font_size", "small")
    title_font_name = config.get("title_font", "tb"); title_font_size = config.get("title_font_size", "small")
    author_font_name = config.get("author_font", "tb"); author_font_size = config.get("author_font_size", "small")

    # Determine the actual Starlark font for each element
    quote_before_font = get_font_details(quote_before_font_name, quote_before_font_size)
    time_ref_font = get_font_details(time_ref_font_name, time_ref_font_size)
    quote_after_font = get_font_details(quote_after_font_name, quote_after_font_size)
    title_font = get_font_details(title_font_name, title_font_size)
    author_font = get_font_details(author_font_name, author_font_size)

    # --- Timezone Logic ---
    user_tz_selection = config.get("user_timezone", "$tz"); device_tz = config.get("$tz"); default_tz = "America/New_York"
    tz = default_tz
    if user_tz_selection and user_tz_selection != "$tz": tz = user_tz_selection
    elif device_tz: tz = device_tz
    now = time.now().in_location(tz)
    # --- End Timezone Logic ---

    current_hour_str = now.format("15")
    next_hour_time = now + time.hour
    next_hour_str = next_hour_time.format("15")
    minute_str = now.format("04")

    # --- Fetch Logic ---
    current_hour_data = fetch_hour_data(current_hour_str, now)
    fetch_hour_data(next_hour_str, now) # Pre-fetch next hour
    # --- End Fetch Logic ---

    if not current_hour_data: return render_error(quote_color, bg_color, quote_before_font) # Use quote_before font

    quote = get_quote_for_minute(current_hour_data, minute_str)
    if not quote: return render_error(quote_color, bg_color, quote_before_font) # Use quote_before font

    # Render the scrolling quote, passing all determined fonts and renamed colors
    return render_scrolling_quote(
        quote = quote, quote_color = quote_color, time_ref_color = time_ref_color, author_color = author_color, title_color = title_color, bg_color = bg_color,
        quote_before_font = quote_before_font, time_ref_font = time_ref_font, quote_after_font = quote_after_font,
        title_font = title_font, author_font = author_font,
    )