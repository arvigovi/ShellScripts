#variables
pcf8574=0xff #represents the PCF8574 permanent register (virtual)

setRed1=0xdf # to be ANDed to pcf8574 to turn on RED LED1
setRed2=0xef # to be ANDed to pcf8574 to turn on RED LED2
resetRed1=0x20 # to be ORed to pcf8574 to turn off RED LED1
resetRed2=0x10 # to be ORed to pcf8574 to turn off RED LED2
setLP=0x7f # to be ANDed to pcf8574 to turn on LP LED
resetLP=0x80 # to be ORed to pcf8574 to turn off LP LED

i2cset -f -y 0 0x27 1 $pcf8574 #pcf8574 init state


/HiSpdLogBin/gpsinit.sh #configure GPS
sleep 10 # wait for gpsd to accquire GPS and begin running 
		
printf -v pcf8574 '0x%x' $[pcf8574&setRed1]
i2cset -f -y 0 0x27 1 $pcf8574
		
		
while : ;
do
{
		printf -v pcf8574 '0x%x' $[pcf8574&setLP]
		i2cset -f -y 0 0x27 1 $pcf8574
        
		sw=$(i2cget -y 0 0x27)
        while [ $((sw&2)) = 2]; do #just keep waiting here until SW1 press
                        sleep 1
                        sw=$(i2cget -y 0 0x27)
                        echo "In - 1"
        done
		printf -v pcf8574 '0x%x' $[pcf8574|resetLP]
		i2cset -f -y 0 0x27 1 $pcf8574
		printf -v pcf8574 '0x%x' $[pcf8574&setRed2] #set Red2 to indicate start of logging
		i2cset -f -y 0 0x27 1 $pcf8574

		GPSDATE=`gpspipe -w | head -10 | grep TPV | sed -r 's/.*"time":"([^"]*)".*/\1/' | head -1`
        FilNameGPS=GPSLog$GPSDATE.csv
        FilNameAccel=AccelLog$GPSDATE.csv
       
		sudo /HiSpdLogBin/adxlLog -d -f /run/shm/$FilNameAccel
		sudo /HiSpdLogBin/gpsLog -d -f /run/shm/$FilNameGPS
    
		#echo "Log Start"
        sleep 5 # Minimum file sample = 5seconds
		
		printf -v pcf8574 '0x%x' $[pcf8574&setLP]
		i2cset -f -y 0 0x27 1 $pcf8574
        sw=$(i2cget -y 0 0x27)
        while [ $((sw&4)) = 4 ]; do #just keep waiting here until SW2 press
                        sleep 1
                        sw=$(i2cget -y 0 0x27)
                        echo "In - 2"
        done
		
		printf -v pcf8574 '0x%x' $[pcf8574|resetRed2]
		i2cset -f -y 0 0x27 1 $pcf8574
		printf -v pcf8574 '0x%x' $[pcf8574|resetLP]
		i2cset -f -y 0 0x27 1 $pcf8574
        
		sudo killall adxlLog
		sudo killall gpsLog
        sleep 0.5 #give the processes some time to shutdown
		
		sudo cp /run/shm/$FilNameAccel /HiSpdLogData
		sudo cp /run/shm/$FilNameGPS /HiSpdLogData
        #echo "Log Stop"
		
		sleep 3
		#long press SW2 to Halt
		sw=$(i2cget -y 0 0x27)
		if [ $((sw&4)) = 0 ]; then
			printf -v pcf8574 '0x%x' $[pcf8574|resetGreen]
			i2cset -f -y 0 0x27 1 $pcf8574
			sudo halt
		fi
		
}
done

