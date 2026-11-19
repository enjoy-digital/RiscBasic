10 REM GUESS THE NUMBER - TINY BASIC DEMO
20 PRINT "Guess my number from 1 to 100"
30 PRINT "Press a key to start"
40 R=R+1: K=KEY: IF K=0 THEN 40
50 N=(RND(100)+R) MOD 100+1: T=0
60 INPUT "Your guess";A
70 T=T+1: D=ABS(A-N)
80 IF D=0 THEN 130
90 IF D<=5 THEN PRINT "Very close! ";
100 IF A<N THEN PRINT "Higher!"
110 IF A>N THEN PRINT "Lower!"
120 GOTO 60
130 PRINT "Right, it is ";N;" - found in ";T;" tries"
140 INPUT "Again (1 = yes)";A
150 IF A=1 THEN 20
160 PRINT "Bye"
