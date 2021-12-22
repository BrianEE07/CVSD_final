if ( $?prompt ) then


####a###############################################################
## Cadence                                                         #
####################################################################
	source /usr/cad/cadence/cshrc
        source /usr/cad/cadence/CIC//confrml.cshrc
###################################################################
# Calibre                                                         #
###################################################################
	source /usr/mentor/CIC/calibre.cshrc
 
###################################################################
# Debussy $ Verdi                                                 #
###################################################################
#	source /usr/spring_soft/CIC/debussy.cshrc 
#	source /usr/spring_soft/CIC/verdi.cshrc 
#	source /usr/cad/cadence/CIC/edi.cshrc
 
###################################################################
# Synopsys                                                        #
###################################################################
#	source /usr/cad/synopsys/cshrc
	source /usr/cad/synopsys/CIC/synthesis.cshrc
	source /usr/cad/synopsys/CIC/license.csh
	source /usr/cad/synopsys/CIC/spyglass.cshrc
        source /usr/cad/synopsys/CIC/primetime.cshrc
        source /usr/cad/synopsys/CIC/vcs.cshrc
###################################################################
# Cadence Formal                                                  #
###################################################################
#	source /usr/cad/cadence/jasper/cur/cshrc


###################################################################
# Innovus                                                         #
###################################################################
	source /home/raid7_4/raid1_1/linux/innovus/CIC/license.cshrc
	source /home/raid7_4/raid1_1/linux/innovus/CIC/innovus.cshrc

	#source /home/raid7_4/raid1_1/linux/cadence2012/VIPCAT/vipcat_11.30.065_24_Sep_2019_08_15_01/demo.sh


#set path=(/usr/cad/synopsys/customexplorer/cur/bin $path)
set path=(/usr/cad/spring_soft/laker/cur/bin $path)

endif
