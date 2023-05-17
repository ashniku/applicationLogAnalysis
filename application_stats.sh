
#!/bin/bash

#Need to install below for date function to work
#brew install dateutils

fgrep -iw "TASK_STARTED]" $1 | awk '{print $1 " " $2 " " $9$10 " " $11}' | tr -d "," > start.txt

fgrep -iw "TASK_FINISHED]" $1 | awk '{print $1 " " $2 " "  $9$10 " "$11 " " $14 " "$15 " " $16}'| tr -d "," | grep -i "status=SUCCEEDED"> fin.txt

fgrep -iw "TASK_FINISHED]" $1 | awk '{print $1 " " $2 " "  $9$10 " "$11 " " $14 " "$15 " " $16}'| tr -d "," | grep -i "status=KILLED"> killed.txt

isStartEmpty="start.txt"


if [ -s "$isStartEmpty" ]; then
        awk '{print $3}' start.txt | sort |uniq | awk -F "=" '{print $2}' > startcount.txt
        awk '{print $3}' fin.txt | sort |uniq | awk -F "=" '{print $2}' > fincount.txt 
        awk '{print $3}' killed.txt | sort |uniq | awk -F "=" '{print $2}' > killcount.txt 

        echo
        echo

        #Check AM time. If AM spends > 2 Mins report this.

        getStartAMTime=`fgrep -iw "Running DAG" $1 | awk '{print $1 " " $2}' | sed 's/.......$//'` #Take Starttime of AM 
        getStartTaskContainerTime=`cat start.txt| awk '{print $1 " " $2}' | sed 's/......$//'|  head -n 1` #get the start time for the first task container
        start_time_am=$(date -j -f "%Y-%m-%d %H:%M" "${getStartAMTime}" "+%s") #compute start time in MAC format
        start_time_taskcontainer=$(date -j -f "%Y-%m-%d %H:%M" "${getStartTaskContainerTime}" "+%s") #compute end time in MAC format
        time_diff_am=$((start_time_taskcontainer - start_time_am)) #Find the time taken by AM to launch first container
        echo "Application Master"
        echo "====================="
        echo "Start Time :" $getStartAMTime
        echo "Task Container Launched :" $getStartTaskContainerTime
        echo "Time difference in seconds for Application Master between launched and launching first container: $time_diff_am" 
        if [ $time_diff_am -gt 60 ] 
                then
                    echo
                    echo "The time difference is more then 1 minute, please check if the time spent is more in Split sizing or check if the queue/resources are free."             
        fi
        echo 
        echo

        rm -fr timetaken.txt
        isCompleted=1
        isKilled=0
          while read -r startcont
                do
                   echo "${startcont} :"
                   echo "====================="
                   starttime=`fgrep -iw $startcont start.txt| awk '{print $1 " " $2}' | sed 's/......$//'|  head -n 1 ` #get the start time for all the phases. This will get the starttime for the First container on that phase

                   echo "Start Time :" $starttime
                   totalStartCount=`fgrep -iw $startcont start.txt | wc -l|tr -d ' '` #Get the total count of containers started on each phase
                   echo "Total Started $startcont: $totalStartCount"
                   echo
                   fincont=$startcont
                   
                   endtime=`fgrep -iw $fincont fin.txt| awk '{print $1 " " $2}' | sed 's/......$//'|tail -n 1 ` #get the end time for all the phases.This will get the endtime for the last container on that phase
                   echo "End Time :" $endtime
                   totalEndCount=`fgrep -iw $fincont fin.txt | wc -l |tr -d ' '` #Get the total count of containers finished on each phase
                   echo "Total Ended $fincont: $totalEndCount"
          
                   completedCount=$((totalStartCount - totalEndCount))
                   

                   #Check ithe phases are completed,if start and finished count does not tally,then the application is not finished.
                    isSkewed=1
                   if [ $completedCount -eq 0 ]
                  then
                   start_time=$(date -j -f "%Y-%m-%d %H:%M" "${starttime}" "+%s") #compute start time in MAC format
                   end_time=$(date -j -f "%Y-%m-%d %H:%M" "${endtime}" "+%s") #compute end time in MAC format
                   time_diff=$((end_time - start_time)) #Find the time difference 
                   echo "Time difference in seconds for ${fincont}: $time_diff"  
                   completedCount=$((totalStartCount - totalEndCount))
                   echo "$fincont $time_diff"  >> timetaken.txt
                    echo "$fincont phase is completed"

                  elif [ $completedCount -eq $totalStartCount ]
                  then
                    isCompleted=0
                    echo "$fincont phase is not yet started to execute and it is waiting for the previous phase or few containers are spawned for heavy load,hence taking time"

                 #echo "The application is not completed and application is not collected properly. Finished containers are more then Started containers. Please collect again. "

                  else
                  start_time=$(date -j -f "%Y-%m-%d %H:%M" "${starttime}" "+%s") #compute start time in MAC format
                   end_time=$(date -j -f "%Y-%m-%d %H:%M" "${endtime}" "+%s") #compute end time in MAC format
                   time_diff=$((end_time - start_time)) #Find the time difference 
                   echo "Time difference in seconds for ${fincont}: $time_diff"  
                   completedCount=$((totalStartCount - totalEndCount))
                    echo "$fincont $time_diff"  >> timetaken.txt
                    echo "$fincont phase is not complete"
                    if echo $fincont | grep -q "Map"; then # Skewness does not happen in Map phase,may be small files or yarn is slow. There is a fileter condition.
                       echo "There may be small files in the Map Phase or reading the files takes long time. Check fin.txt and grab the attemptId. Check the Split sizing too."
                       echo "Check below taskid's"
                       echo
                       cat fin.txt | fgrep -iw $fincont | awk '{print $4}'| cut -c 8- | sort > skewfin.txt
                       cat start.txt | fgrep -iw $fincont | awk '{print $4}'| cut -c 8- | sort > skewstart.txt
                       echo "Below taskid is not completed and might have small files issue or taking long time. Check the taskid"
                       echo
                       comm -23 skewstart.txt skewfin.txt 
                       rm -fr  skewstart.txt skewfin.txt    
                    else
                      echo "There may be skewness in this phase"
                       cat fin.txt | fgrep -iw $fincont | awk '{print $4}'| cut -c 8- | sort > skewfin.txt
                       cat start.txt | fgrep -iw $fincont | awk '{print $4}'| cut -c 8- | sort > skewstart.txt
                       echo "Below taskid is not completed and might have skewness"
                       echo
                       comm -23 skewstart.txt skewfin.txt 
                       rm -fr  skewstart.txt skewfin.txt    
                    fi
                    isCompleted=0
                    
                  fi

                   echo "+++++++++++++++++++++++++++++++++++++++" 
                   echo
                   echo
                done < startcount.txt 

         
        #Check if the application is completed or not
        if [ $isCompleted -eq 1 ] 
                then
                    echo "The Application is Completed"
        else
         echo "The application is not completed. The application was either KILLED or Logs collected  when the application was still RUNNING."
        fi  

          
         #get the max time taken
           max=$(sort -nrk2 timetaken.txt | head -n 1 | awk '{print $2}')
           grep $max timetaken.txt > maxtimetaken.txt
         
          

          
        echo
        echo

        #Get the taskID for the phase which took most time. This collect the taskid that took most time
         

        if [ $isCompleted -eq 1 ] 
                then
                    echo
                     echo
                     echo
                     echo "This prints the last takid that took most time.Please check fin.txt to check the other taskid in that phase that took time. The other taskid's timetaken will be less then the printed below: "
                     echo
                     echo "Below are the phases that took most time:"
                     echo "==================================="
                    while read -r maxtime
                    do
                        getPhase=`echo $maxtime | awk '{print $1}'`
                        getTaskid=`fgrep -iw  $getPhase fin.txt| awk '{print $4}' | cut -c 8- | tail -n 1`
                        getAttemptId=`fgrep -iw  $getPhase fin.txt| awk '{print $7}' | cut -c 21- | tail -n 1`
                        echo "$getPhase   $getTaskid  $getAttemptId"         
                    done < maxtimetaken.txt
        fi


        #Check if the application is killed and set the variable so that we canget the taskid's in the next step.This is not a required step but do not want to delete,not to break things :P
         iskilled=0     
        while read -r killtimeCheck
           do
             checkKilledPresent=`echo $killtimeCheck | awk '{print $6}' `
               if [ "$checkKilledPresent" == "status=KILLED" ] 
                then
                    iskilled=1 
              fi                          
          done < killed.txt 

        #This is required as many phases are spawned and killed ,but not recorded in start.txt. Need to find the common between them
        cat  killed.txt | awk '{print $3 " " $4}'| sort  > killsort.txt
        cat start.txt | awk '{print $3 " " $4}'| sort > startsort.txt
        comm -12 startsort.txt killsort.txt > commsort.txt


        #Display the taskID's for Killed ones. Those are pottential time consumers

        if [ $iskilled -eq 1 ] 
          then  
            echo "Below Taskid's were killed and time may be taken on these phases. Check the attemptid for those phases."
            echo 
          while read -r killtimeCheck
           do
             phase=`echo $killtimeCheck | awk '{print $1}'| cut -c 12-`
             taskid=`echo $killtimeCheck | awk '{print $2}'| cut -c 8-`
             echo "$phase  $taskid"                       
          done < commsort.txt
        fi


        echo

        #Delete the temporary files
          rm -fr startcount.txt  fincount.txt  timetaken.txt maxtime.txt skew.txt maxtimetaken.txt killsort.txt startsort.txt commsort.txt


        echo
        echo
        echo "Note: The script will produce incorrect results,if the application is not collected properly."
        echo
        echo "There may be chances the script may break. Please reach out to akpatra@cloudera.com for the feedback "
        echo
        echo




   

else
    echo
    echo
    echo "The containers are not started. The issue is with Yarn queue or AM is taking time on Computing Splts."  
    echo "The application is not completed"
    echo
    echo "Please grep for 'Allocated: <memory:0' and check,if resorces are not assigned."
    echo "Note: The script will produce incorrect results,if the application is not collected properly."
    echo
    echo "There may be chances the script may break. Please reach out to akpatra@cloudera.com for the feedback "
    echo

fi


