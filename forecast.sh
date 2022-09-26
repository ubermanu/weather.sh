#!/bin/bash

# TODO: Add in sunrise/sunset calcuations
#Derived from https://gist.githubusercontent.com/elucify/c7ccfee9f13b42f11f81/raw/9f27e072aadc4df6f84d515309c82585a8a13d8e/gistfile1.txt

RESTORE=$(echo -en '\033[0m')
RED=$(echo -en '\033[00;31m')
GREEN=$(echo -en '\033[00;32m')
YELLOW=$(echo -en '\033[00;33m')
BLUE=$(echo -en '\033[00;34m')
MAGENTA=$(echo -en '\033[00;35m')
PURPLE=$(echo -en '\033[00;35m')
CYAN=$(echo -en '\033[00;36m')
LGRAY=$(echo -en '\033[00;37m')
LRED=$(echo -en '\033[01;31m')
LGREEN=$(echo -en '\033[01;32m')
LYELLOW=$(echo -en '\033[01;33m')
LBLUE=$(echo -en '\033[01;34m')
LMAGENTA=$(echo -en '\033[01;35m')
LPURPLE=$(echo -en '\033[01;35m')
LCYAN=$(echo -en '\033[01;36m')
WHITE=$(echo -en '\033[01;37m')

########################################################################
# Setting Defaults
########################################################################

apiKey=""
defaultLocation=""
Inline="false"
Terminal="false"
degreeCharacter="c"
data=0
lastUpdateTime=0
FeelsLike=0
dynamicUpdates=0
UseIcons="true"
colors="false"

########################################################################
# Reading in rc
########################################################################
ConfigFile="$HOME/.config/weather_sh.json"

if [ "$1" == "-r" ]; then
    shift
    ConfigFile="$1"
    shift
fi

if [ -f "$ConfigFile" ]; then
    apiKey=$(jq -r '.apiKey' "$ConfigFile")
    defaultLocation=$(jq -r '.cityId' "$ConfigFile")
    degreeCharacter=$(jq -r '.degreeUnit' "$ConfigFile")
    UseIcons=$(jq -r '.icons' "$ConfigFile")
    colors=$(jq -r '.colors' "$ConfigFile")
fi

########################################################################
# Reading in options
########################################################################

while [ $# -gt 0 ]; do
option="$1"
    case $option
    in
    -k) apiKey="$2"
    shift
    shift ;;
    -l) defaultLocation="$2"
    shift
    shift ;;
    -d) dynamicUpdates=1
    shift ;;
    -t) Terminal="true"
    shift ;;
    -y) Inline="true"
    shift ;;
    -f) degreeCharacter="f"
    shift ;;
    -n) UseIcons="false"
    shift ;;
    -p) CachePath="$2"
    shift
    shift ;;
    -c) colors="true"
    shift ;;
    esac
done

if [ -z $apiKey ]; then
    echo "No API Key specified in rc, script, or command line."
    exit
fi

#Is it City ID or a string?
case $defaultLocation in
    ''|*[!0-9]*) CityID="false" ;;
    *) CityID="true" ;;
esac


########################################################################
# Do we need a new datafile? If so, get it.
########################################################################

if [ -z "${CachePath}" ]; then
    dataPath="/tmp/fore-$defaultLocation.json"
else
    dataPath="${CachePath}/fore-$defaultLocation.json"
fi

if [ ! -e $dataPath ]; then
    touch $dataPath
    if [ "$CityID" = "true" ]; then
        data=$(curl -s "http://api.openweathermap.org/data/2.5/forecast?id=$defaultLocation&units=metric&appid=$apiKey")
    else
        data=$(curl -s "http://api.openweathermap.org/data/2.5/forecast?q=$defaultLocation&units=metric&appid=$apiKey")
    fi

    echo $data > $dataPath
else
    data=$(cat $dataPath)
fi

    check=$(echo "$data" | grep -c -e '"cod":"40')
    check2=$(echo "$data" | grep -c -e '"cod":"30')
    sum=$(( $check + $check2 ))
    if [ $sum -gt 0 ]; then
        exit 99
    fi

lastUpdateTime=$(($(date +%s) -600))

while true; do
    lastfileupdate=$(date -r $dataPath +%s)
    if [ $(($(date +%s)-$lastfileupdate)) -ge 600 ]; then
        if [ "$CityID" = "true" ]; then
            data=$(curl -s "http://api.openweathermap.org/data/2.5/forecast?id=$defaultLocation&units=metric&appid=$apiKey")
        else
            data=$(curl -s "http://api.openweathermap.org/data/2.5/forecast?q=$defaultLocation&units=metric&appid=$apiKey")
        fi
        echo $data > $dataPath
    else
        if [ "$Inline" != "true" ]; then
            echo "Cache age: $(($(date +%s)-$lastfileupdate)) seconds."
        fi
    fi

    if [ $(($(date +%s)-$lastUpdateTime)) -ge 600 ]; then
        lastUpdateTime=$(date +%s)


        ########################################################################
        # Location Data
        ########################################################################
        Station=$(echo $data | jq -r .city.name)
        #Lat=$(echo $data | jq -r .coord.lat)
        #Long=$(echo $data | jq -r .coord.lon)
        #Country=$(echo $data | jq -r .sys.country)
        NumEntries=$(echo $data |jq -r .cnt)
        let i=0

        while [ $i -lt $NumEntries ]; do
            # Get the date...unix format
            NixDate[$i]=$(echo $data | jq -r  .list[$i].dt  | tr '\n' ' ')
            ####################################################################
            # Current conditions (and icon)
            ####################################################################
            if [ "$UseIcons" = "true" ]; then
                icons[$i]=$(echo $data | jq -r .list[$i].weather[] | jq -r .icon | tr '\n' ' ')
                iconval=${icons[$i]%?}
                case $iconval in
                    01*) icon[$i]="☀️";;
                    02*) icon[$i]="🌤";;
                    03*) icon[$i]="🌥";;
                    04*) icon[$i]="☁";;
                    09*) icon[$i]="🌧";;
                    10*) icon[$i]="🌦";;
                    11*) icon[$i]="🌩";;
                    13*) icon[$i]="🌨";;
                    50*) icon[$i]="🌫";;
                esac
            else
                icon[$i]=""
            fi
            ShortWeather[$i]=$(echo $data | jq -r .list[$i].weather[] | jq -r .main | tr '\n' ' '| awk '{$1=$1};1' )
            LongWeather[$i]=$(echo $data | jq -r .list[$i].weather[] | jq -r .description | sed -E 's/\S+/\u&/g' | tr '\n' ' '| awk '{$1=$1};1' )
            Humidity[$i]=$(echo $data | jq -r .list[$i].main.humidity | tr '\n' ' '| awk '{$1=$1};1' )
            CloudCover[$i]=$(echo $data | jq -r .list[$i].clouds.all | tr '\n' ' '| awk '{$1=$1};1' )

            ####################################################################
            # Parse Wind Info
            ####################################################################
            WindSpeed[$i]=$(echo $data | jq -r .list[$i].wind.speed | tr '\n' ' ' | awk '{$1=$1};1' )

            #Conversion
            if  [ "$degreeCharacter" = "f" ]; then
                WindSpeed[$i]=$(echo "scale=2; ${WindSpeed[$i]}*0.6213712" | bc | xargs printf "%.2f" | awk '{$1=$1};1' )
                windunit="mph"
            else
                windunit="kph"
            fi

            ####################################################################
            # Temperature
            ####################################################################
            tempinc[$i]=$(echo $data | jq -r .list[$i].main.temp | tr '\n' ' ')
            temperature[$i]=$tempinc[$i]
            if  [ "$degreeCharacter" = "f" ]; then
                temperature[$i]=$(echo "scale=2; 32+1.8*${tempinc[$i]}" | bc)
            fi
            i=$((i + 1))
        done
    fi


    AsOf=$(date +"%Y-%m-%d %R" -d @$lastfileupdate)
    TomorrowDate=$(date -d '+1 day' +"%s")
    NowHour=$(date +"%-H")
    NowLow=$((NowHour + 1))
    NowHigh=$((NowHour - 1))
    if [ "$Inline" = "false" ]; then
        Terminal="true"
    fi
    if [ "$Inline" = "true" ]; then
        if [ "$colors" = "true" ]; then
            let i=0
            bob=""
            while [ $i -lt 5 ]; do
                CastDate=$(date +"%s" -d @${NixDate[$i]})
                if [ $CastDate -le $TomorrowDate ]; then
                    ShortDate=$(date +"%R" -d @${NixDate[$i]})
                    bob=$(printf "%s %-4s%-2s %-4s |" "$bob" "$ShortDate:" "${ShortWeather[$i]}" "${temperature[$i]}°${degreeCharacter^^}")
                fi
                i=$((i + 1))
            done
        else
            let i=0
            bob=""
            while [ $i -lt 5 ]; do
                CastDate=$(date +"%s" -d @${NixDate[$i]})
                if [ $CastDate -le $TomorrowDate ]; then
                    ShortDate=$(date +"%R" -d @${NixDate[$i]})
                    bob=$(printf "%s %-5s %-6s %-4s |" "$bob" "$ShortDate:" "${ShortWeather[$i]}" "${temperature[$i]}°${degreeCharacter^^}")
                fi
                i=$((i + 1))
            done
        fi

        #bob=$(echo "$icon $ShortWeather $temperature°${degreeCharacter^^}")
        #bob
        echo "$bob"
    fi
    if [ "$Terminal" = "true" ]; then
        if [ "$colors" = "true" ]; then
            echo "Forecast for $Station as of: ${YELLOW}$AsOf${RESTORE} "
        else
            echo "Forecast for $Station as of: $AsOf "
        fi
        let i=0
        while [ $i -lt 40 ]; do
            CastDate=$(date +"%s" -d @${NixDate[$i]})
            if [ $CastDate -le $TomorrowDate ]; then
                ShortDate=$(date +"%m/%d@%R" -d @${NixDate[$i]})
                if [ "$colors" = "true" ]; then
                    printf "${YELLOW}%-11s${RESTORE}: ${CYAN}%-2s%-16s${RESTORE} Temp:${CYAN}%-6s${RESTORE} Wind:${MAGENTA}%-6s${RESTORE} Humidity:${GREEN}%-4s${RESTORE} Clouds:${GREEN}%-4s${RESTORE}\n" "$ShortDate" "${icon[$i]} " "${LongWeather[$i]}" "${temperature[$i]}°${degreeCharacter^^}" "${WindSpeed[$i]}$windunit" "${Humidity[$i]}%" "${CloudCover[$i]}%"
                else
                    printf "%-12s %-2s%-20s %-15s %-14s %-14s %-14s\n" "$ShortDate:" "${icon[$i]} " "${LongWeather[$i]}" "Temp:${temperature[$i]}°${degreeCharacter^^}" "Wind:${WindSpeed[$i]}$windunit" "Humidity:${Humidity[$i]}%" "Cloud Cover:${CloudCover[$i]}%"
                fi
            else
                CastHour=$(date +"%-H" -d @${NixDate[$i]})
                if [ "$CastHour" -ge "$NowHigh" ] && [ "$CastHour" -le "$NowLow" ]; then
                    ShortDate=$(date +"%m/%d@%R" -d @${NixDate[$i]})
                    if [ "$colors" = "true" ]; then
                        printf "${RED}%-11s${RESTORE}: ${CYAN}%-2s%-16s${RESTORE} Temp:${CYAN}%-6s${RESTORE} Wind:${MAGENTA}%-6s${RESTORE} Humidity:${GREEN}%-4s${RESTORE} Clouds:${GREEN}%-4s${RESTORE}\n" "$ShortDate" "${icon[$i]} " "${LongWeather[$i]}" "${temperature[$i]}°${degreeCharacter^^}" "${WindSpeed[$i]}$windunit" "${Humidity[$i]}%" "${CloudCover[$i]}%"
                    else
                        printf "%-12s %-2s%-20s %-15s %-14s %-14s %-14s\n" "$ShortDate:" "${icon[$i]} " "${LongWeather[$i]}" "Temp:${temperature[$i]}°${degreeCharacter^^}" "Wind:${WindSpeed[$i]}$windunit" "Humidity:${Humidity[$i]}%" "Cloud Cover:${CloudCover[$i]}%"
                    fi
                fi
            fi
            i=$((i + 1))
        done
        fi
        if [ "$OpenBox" = "true" ]; then
            echo '<openbox_pipe_menu>'
            echo '<separator label="Forecast" />'
            printf '<item label="Forecast for %s as of %s" />\n' "$Station" "$AsOf"
            let i=0
            while [ $i -lt 40 ]; do
                CastDate=$(date +"%s" -d @${NixDate[$i]})
                if [ $CastDate -le $TomorrowDate ]; then
                    ShortDate=$(date +"%m/%d@%R" -d @${NixDate[$i]})
                    printf '<item label="%-12s %-2s%-20s %-15s %-14s %-14s %-14s/>\n' "$ShortDate:" "${icon[$i]} " "${LongWeather[$i]}" "Temp:${temperature[$i]}°${degreeCharacter^^}" "Wind:${WindSpeed[$i]}$windunit" "Humidity:${Humidity[$i]}%" "Cloud Cover:${CloudCover[$i]}%"
                else
                    CastHour=$(date +"%-H" -d @${NixDate[$i]})
                    if [ "$CastHour" -ge "$NowHigh" ] && [ "$CastHour" -le "$NowLow" ]; then
                        ShortDate=$(date +"%m/%d@%R" -d @${NixDate[$i]})
                        printf '<item label="%-12s %-2s%-20s %-15s %-14s %-14s %-14s/>\n' "$ShortDate:" "${icon[$i]} " "${LongWeather[$i]}" "Temp:${temperature[$i]}°${degreeCharacter^^}" "Wind:${WindSpeed[$i]}$windunit" "Humidity:${Humidity[$i]}%" "Cloud Cover:${CloudCover[$i]}%"
                    fi
                fi
                i=$((i + 1))
            done
            echo '</openbox_pipe_menu>'
        fi
        if [ "$HTML" = "true" ]; then
            echo "Forecast for $Station as of: $AsOf  <br  />"
            let i=0
            while [ $i -lt 40 ]; do
                CastDate=$(date +"%s" -d @${NixDate[$i]})
                if [ $CastDate -le $TomorrowDate ]; then
                    ShortDate=$(date +"%m/%d@%R" -d @${NixDate[$i]})
                    printf "%-12s %-2s%-20s %-15s %-14s %-14s %-14s<br  />\n" "$ShortDate:" "${icon[$i]} " "${LongWeather[$i]}" "Temp:${temperature[$i]}°${degreeCharacter^^}" "Wind:${WindSpeed[$i]}$windunit" "Humidity:${Humidity[$i]}%" "Cloud Cover:${CloudCover[$i]}%"
                else
                    CastHour=$(date +"%-H" -d @${NixDate[$i]})
                    if [ $CastHour -ge $NowHigh ] && [ $CastHour -le $NowLow ]; then
                        ShortDate=$(date +"%m/%d@%R" -d @${NixDate[$i]})
                        printf "%-12s %-2s%-20s %-15s %-14s %-14s %-14s<br  />\n" "$ShortDate:" "${icon[$i]} " "${LongWeather[$i]}" "Temp:${temperature[$i]}°${degreeCharacter^^}" "Wind:${WindSpeed[$i]}$windunit" "Humidity:${Humidity[$i]}%" "Cloud Cover:${CloudCover[$i]}%"
                    fi
                fi
                i=$((i + 1))
            done
        fi
    if [ $dynamicUpdates -eq 0 ]; then
        break
    fi
done
