#!/bin/bash
# weather.sh: A Waybar weather module script with Celsius & icons

# Fetch weather data in JSON format from wttr.in
WEATHER_JSON=$(curl -s 'wttr.in/?format=j1')

if [ -n "$WEATHER_JSON" ]; then
  # Extract current temperature in Celsius and weather description
  TEMP=$(echo "$WEATHER_JSON" | jq -r '.current_condition[0].temp_C')
  CONDITION=$(echo "$WEATHER_JSON" | jq -r '.current_condition[0].weatherDesc[0].value')

  # Assign an icon based on weather condition
  case "$CONDITION" in
  "Clear" | "Sunny") ICON="" ;;                                  # Clear sky
  "Partly cloudy") ICON="" ;;                                    # Partly cloudy
  "Cloudy" | "Overcast") ICON="" ;;                              # Cloudy
  "Mist" | "Fog" | "Haze") ICON="" ;;                            # Mist/Fog
  "Patchy rain possible" | "Light rain" | "Showers") ICON="" ;;  # Light rain
  "Moderate rain" | "Heavy rain" | "Torrential rain") ICON="" ;; # Heavy rain
  "Patchy snow possible" | "Light snow") ICON="" ;;              # Light snow
  "Moderate snow" | "Heavy snow") ICON="" ;;                     # Heavy snow
  "Thunderstorm" | "Thundery outbreaks possible") ICON="" ;;     # Thunderstorm
  "Drizzle") ICON="" ;;                                          # Drizzle
  "Sleet") ICON="" ;;                                            # Sleet
  *) ICON="" ;;                                                  # Default: Cloudy
  esac

  # Output JSON in the format Waybar expects
  echo "{\"temp\": \"$TEMP°C\", \"condition\": \"$CONDITION\", \"icon\": \"$ICON\"}"
else
  # Fallback in case of an error fetching weather data
  echo "{\"temp\": \"N/A\", \"condition\": \"Unavailable\", \"icon\": \"\"}"
fi
