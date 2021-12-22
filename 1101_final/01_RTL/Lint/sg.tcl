# build project
new_project ./cvsd_lint -force

# read file
read_file -type sourcelist ./rtl_only.f

# assign design top
set_option top GSIM

# set waive file

# set goal and add rule
define_goal cvsd_lint -policy { lint } {
## reset rules
set_goal_option rules W392                 
set_goal_option overloadrules W392+severity=ERROR
set_goal_option rules W395                 
set_goal_option rules W402b                
set_goal_option rules W402a                
set_goal_option rules W448                 
set_goal_option overloadrules W448+severity=ERROR

## usage rules
set_goal_option rules W34 
set_goal_option rules W120
set_goal_option overloadrules W120+severity=ERROR
set_goal_option rules W121
set_goal_option overloadrules W121+severity=ERROR
set_goal_option rules W123
set_goal_option overloadrules W123+severity=ERROR
set_goal_option rules W143
set_goal_option rules W154                 
set_goal_option rules W188                 
set_goal_option overloadrules W188+severity=ERROR
set_goal_option rules W240
set_goal_option overloadrules W240+severity=ERROR
set_goal_option rules W241
set_goal_option rules W423                 
set_goal_option overloadrules W423+severity=ERROR
set_goal_option rules W468                 
set_goal_option rules W493                 
set_goal_option rules W494                 
set_goal_option rules W495                 
set_goal_option rules W497                 
set_goal_option rules W498                 
set_goal_option rules W528                 

## lint_elab_rules
set_goal_option rules W17                  
set_goal_option rules W69                  
set_goal_option overloadrules W69+severity=ERROR
set_goal_option rules W110                 
set_goal_option overloadrules W110+severity=ERROR
set_goal_option rules W116                 
set_goal_option overloadrules W116+severity=ERROR
set_goal_option rules W122                 
set_goal_option overloadrules W122+severity=ERROR
set_goal_option rules W162                 
set_goal_option rules W163                 
set_goal_option rules W164b                
set_goal_option overloadrules W164b+severity=ERROR
set_goal_option rules W164a                
set_goal_option overloadrules W164a+severity=ERROR
set_goal_option rules W263                 
set_goal_option rules W316                 
set_goal_option rules W328                 
set_goal_option rules W362
set_goal_option rules W446
set_goal_option rules W453
set_goal_option rules W456
set_goal_option rules W456a                
set_goal_option rules W484                 
set_goal_option rules W486                 
set_goal_option rules W488                 
set_goal_option rules W502                 
set_goal_option overloadrules W502+severity=ERROR
set_goal_option rules W504                 
set_goal_option rules W552                 
set_goal_option rules W553                 

## synthesis rules
set_goal_option rules W239                 
set_goal_option rules W293                 
set_goal_option overloadrules W293+severity=ERROR
set_goal_option rules W294                 
set_goal_option overloadrules W294+severity=ERROR
set_goal_option rules W339a                
set_goal_option overloadrules W339a+severity=ERROR
set_goal_option rules W430                 
set_goal_option rules W442f                
set_goal_option overloadrules W442f+severity=ERROR
set_goal_option rules W442c                
set_goal_option rules W442b                
set_goal_option overloadrules W442b+severity=ERROR
set_goal_option rules W442a                
set_goal_option rules W464                 
set_goal_option overloadrules W464+severity=ERROR
set_goal_option rules W505                 

## expression rules
set_goal_option rules W159
set_goal_option rules W180
set_goal_option rules W224
set_goal_option overloadrules W224+severity=ERROR
set_goal_option rules W289
set_goal_option rules W341
set_goal_option rules W342
set_goal_option overloadrules W342+severity=ERROR
set_goal_option rules W343
set_goal_option overloadrules W343+severity=ERROR
set_goal_option rules W443                 
set_goal_option rules W444                 
set_goal_option rules W467                 
set_goal_option rules W490                 
set_goal_option rules W561                 
set_goal_option rules W563                 
set_goal_option rules W575                 
set_goal_option rules W576                 
             
## clock rules
set_goal_option rules W391
set_goal_option rules W401
set_goal_option rules W422                 
set_goal_option overloadrules W422+severity=ERROR

## multipledriver rules
set_goal_option rules W323                 
set_goal_option rules W415                 
set_goal_option overloadrules W415+severity=ERROR

## event rules
set_goal_option rules W238                 
set_goal_option rules W245                 
set_goal_option overloadrules W245+severity=ERROR
set_goal_option rules W421                 

## latch rules
set_goal_option rules W18                  

## case rules
set_goal_option rules W187                 
set_goal_option overloadrules W187+severity=ERROR
set_goal_option rules W226                 
set_goal_option overloadrules W226+severity=ERROR
set_goal_option rules W332                 
set_goal_option rules W337                 
set_goal_option overloadrules W337+severity=ERROR
set_goal_option rules W398                 
set_goal_option overloadrules W398+severity=ERROR

## instance rules
set_goal_option rules W146                 
set_goal_option rules W210                 
set_goal_option rules W287c                
set_goal_option overloadrules W287c+severity=ERROR
set_goal_option rules W287b                
set_goal_option rules W287a                

## assign rules
set_goal_option rules W336                 
set_goal_option overloadrules W336+severity=ERROR
set_goal_option rules W414                 
set_goal_option overloadrules W414+severity=ERROR
}

# execute goal
run_goal cvsd_lint

# save project
save_project -force
exit -force
