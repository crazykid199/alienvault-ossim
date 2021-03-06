#!/bin/bash
# snort-rules-default flow control unset/restore auxscript

# ossim_setup.conf option: ids_rules_flow_control=yes/no (default=yes)

# - ids_rules_flow_control=yes

#    do nothing, or restore *.rules if flow control was removed:
#     - restore from tar backup
#     - or from snort-rules-default package if tar restore was failed

# - ids_rules_flow_control=no
#    save current ruleset in a tar backup and remove flow control from $SRC/*.rules



. /lib/lsb/init-functions

BPATH="/etc/snort"
SRC="$BPATH/rules"
BAKNAME="rules-flow_yes.tar.gz"
D_CLEAN="/usr/share/snort-rules-default/d_clean"
PN="ids_rules_flow_control"
#TS=`date +%F_%H:%M:%S`

if [ ! -z "$1" ]; then
	PARM="$1"
else	
	PARM=0
fi

f_restore(){
# Restore from package files:
if [ -d "$D_CLEAN"/etc/snort/rules/ ]; then
	ls "$D_CLEAN"/etc/snort/rules/*.rules >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -n " restore rules from snort-rules-default package (please wait)..."
		cp -f "$D_CLEAN"/etc/snort/rules/*.rules "$SRC"
		echo "done."
	else
		log_warning_msg "$D_CLEAN/etc/snort/rules/*.rules not found"
	fi
else
	log_warning_msg "$D_CLEAN/etc/snort/rules/ not found"
fi
}

echo "$PN."

if [ ! -f /etc/ossim/ossim_setup.conf ] ; then
        log_warning_msg "/etc/ossim/ossim_setup.conf not found"
        exit 0
fi

prof=`cat /etc/ossim/ossim_setup.conf  | grep -v "profile=server" | grep profile | cut -d= -f2`
profiles="$(echo $prof | tr ',' ' ')"
SERVER="0"; DATABASE="0"; FRAMEWORK="0"; SENSOR="0"
for p in $profiles ; do
	if [ "$p" == "Server" ]; then SERVER="1"
	elif [ "$p" == "Database" ]; then DATABASE="1"
	elif [ "$p" == "Framework" ]; then FRAMEWORK="1"
	elif [ "$p" == "Sensor" ]; then SENSOR="1"
	else
	echo -e "No profiles found."
	fi
done

if [ "$SENSOR" != "1" ]; then
                echo " profile 'Sensor' not found"
		exit 0
fi

if [ ! -d "$SRC" ]; then
	log_warning_msg "$SRC not found"
	exit 0
fi

prop=$(grep "$PN" /etc/ossim/ossim_setup.conf)
if [ $? -ne 0 ]; then
        log_warning_msg "$PN not found in config"
        exit 0
else
        value=$(grep "$PN" /etc/ossim/ossim_setup.conf | awk -F'=' '{print$2}')
	if [ ! -z $value ]; then
		echo "config value=$value"
		if [ $value = "no" ]; then
	                grep -q "flow:" "$SRC"/*.rules >/dev/null 2>&1
	                if [ $? -eq 1 ]; then
	                        echo " 'flow' already removed. no modification needed."
	                else
# Save tar backup:
				if [ ! -d "$BPATH"/rules_backup ]; then
					mkdir "$BPATH"/rules_backup
				fi
				echo -n " save current ruleset to $BPATH/rules_backup/$BAKNAME..."
				cd "$SRC" && \
	                        tar cfzp "$BPATH"/rules_backup/"$BAKNAME" *.rules >/dev/null 2>&1
				if [ $? -eq 0 ]; then
					echo "done."
				else	
					echo " couldn't save backup!. exiting"
					exit 0
				fi
	                        echo -n " modify installed rules for asymmetric traffic (please wait)..."
# Remove flow:[^;]*;
	                        cd "$SRC" && \
	                        for FI in $(ls *.rules); do
	                                sed -i -e 's/flow:[^;]*;//g' "$FI"
	                        done
	                        echo "done."
				
	                fi
		else
                	if [ $value = "yes" ]; then
				echo -n " checking installed ruleset..."
		                grep -q "flow:" "$SRC"/*.rules >/dev/null 2>&1
		                if [ $? -eq 1 ]; then
					echo " 'flow:' not found. restore:"
					if [ "$PARM" = "--restore-defaults" ]; then
						f_restore
					else
# Restore from tar backup:
						if [ -s "$BPATH"/rules_backup/"$BAKNAME" ]; then
							echo -n " restore $BPATH/rules_backup/$BAKNAME (please wait)..."
							tar xfz "$BPATH"/rules_backup/"$BAKNAME" -C "$SRC"
							echo "done."
							rm -f "$BPATH"/rules_backup/"$BAKNAME" || true
							rmdir "$BPATH"/rules_backup || true
						else
							log_warning_msg "$BPATH/rules_backup/$BAKNAME not found or empty. trying to restore from source:"
							f_restore
						fi
					fi						
				else
					echo " 'flow:' found. no modification needed."
				fi
			else	
				echo " unknown config value."
			fi
	        fi
	else
		echo " config value not found." 
	fi
fi

exit  0
