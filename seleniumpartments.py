import os
import re
import time
import requests
from urllib.parse import urljoin
import folium
from selenium import webdriver
from selenium.webdriver.chrome.service import Service as ChromeService
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup

# The URL to scrape (replace with your actual URL)
base_url = "https://www.padmapper.com/apartments/asheville-nc?box=-82.61432,35.43806,-82.47019,35.68809"

# Configure Chrome options (uncomment headless mode if desired)
options = webdriver.ChromeOptions()
# options.add_argument("--headless")  # Uncomment to run headless

# Initialize the Chrome WebDriver using webdriver_manager
driver = webdriver.Chrome(service=ChromeService(ChromeDriverManager().install()), options=options)

def clean_filename(s):
    """
    Clean the string s to be used as a filename:
      - Replace spaces with underscores.
      - Remove any characters not safe for filenames.
    """
    s = s.replace(" ", "_")
    return re.sub(r'[^\w\-_\.]', '', s)

def download_detail_page(detail_url, filename):
    """
    Opens the detail URL in a new tab, waits for the page to load, 
    and saves the page source to the given filename.
    """
    # Open the detail page in a new tab
    driver.execute_script("window.open(arguments[0]);", detail_url)
    # Switch to the new tab (last in the list)
    driver.switch_to.window(driver.window_handles[-1])
    
    # Wait for the page to load (adjust time if needed or use WebDriverWait)
    time.sleep(3)
    
    # Get the detail page's HTML
    detail_html = driver.page_source
    with open(filename, "w", encoding="utf-8") as f:
        f.write(detail_html)
    print(f"Detail page saved as {filename}")
    
    # Close the detail tab and switch back to the main listing page
    driver.close()
    driver.switch_to.window(driver.window_handles[0])

# This list will hold data (including geocoordinates) for listings that we can map.
listings_data = []

try:
    # Navigate to the base URL (listing page)
    driver.get(base_url)
    
    # Wait for the page to load fully.
    time.sleep(5)
    
    # Get the page source and parse it.
    html = driver.page_source
    soup = BeautifulSoup(html, 'html.parser')
    
    # Create a directory for saving detail pages if it doesn't exist.
    detail_dir = "./Postings"
    os.makedirs(detail_dir, exist_ok=True)
    
    # Also create a directory for images if needed.
    # postings_dir = "./Images"
    # os.makedirs(postings_dir, exist_ok=True)
    
    # Select all listing containers based on the sample HTML.
    listings = soup.select("div.ListItemFull_noGutterRow__jMdAt.ListItemFull_listItemFull__2_slY")
    
    for idx, listing in enumerate(listings, 1):
        # Extract the title.
        title_tag = listing.find("a", class_="ListItemFull_headerText__HlDxW")
        title = title_tag.get_text(strip=True) if title_tag else "No_title"
        
        # Extract the price.
        price_tag = listing.find("span", class_="ListItemFull_text__26sFf")
        price = price_tag.get_text(strip=True) if price_tag else "No_price"
        
        # Extract the address.
        address_container = listing.find("div", class_="ListItemFull_address__ihYsi")
        address = address_container.get_text(strip=True) if address_container else "No_address"
        
        print(f"Listing {idx}:")
        print("  Title  :", title)
        print("  Price  :", price)
        print("  Address:", address)
        
        # Extract the detail page link from the <a> tag.
        detail_url = None
        if title_tag and title_tag.has_attr("href"):
            detail_url = urljoin(base_url, title_tag["href"])
        else:
            print("  No detail link found.")
        
        if detail_url:
            print("  Detail URL:", detail_url)
            # Build a filename using the address and price.
            filename_base = f"{address}-{price}"
            filename_clean = clean_filename(filename_base)
            detail_filename = os.path.join(detail_dir, filename_clean + ".html")
            # Download (i.e. save) the detail page.
            download_detail_page(detail_url, detail_filename)
        else:
            print("  Skipping detail page download due to missing link.")
        
        # Extract coordinates if available.
        lat = None
        lng = None
        geo_span = listing.find("span", itemprop="geo")
        if geo_span:
            lat_tag = geo_span.find("meta", itemprop="latitude")
            lng_tag = geo_span.find("meta", itemprop="longitude")
            if lat_tag and lng_tag:
                lat = lat_tag.get("content")
                lng = lng_tag.get("content")
        
        if lat and lng:
            print("  Coordinates: ", lat, lng)
            listings_data.append({
                "title": title,
                "price": price,
                "address": address,
                "lat": float(lat),
                "lng": float(lng)
            })
        else:
            print("  No coordinates found.")
        
        print("-" * 40)
    
except Exception as e:
    print("An error occurred:", e)
    
finally:
    driver.quit()

# Plot the listings on a map using folium.
if listings_data:
    # Use the coordinates of the first listing as the map center.
    first = listings_data[0]
    map_center = [first["lat"], first["lng"]]
    m = folium.Map(location=map_center, zoom_start=12)
    
    for listing in listings_data:
        popup_text = f"{listing['title']}<br>{listing['address']}<br>{listing['price']}"
        folium.Marker(
            location=[listing["lat"], listing["lng"]],
            popup=popup_text,
            icon=folium.Icon(color="blue", icon="info-sign")
        ).add_to(m)
    
    map_filename = "listings_map.html"
    m.save(map_filename)
    print(f"\nMap with {len(listings_data)} listings saved as '{map_filename}'.")
else:
    print("No geocoordinates found to plot on the map.")
