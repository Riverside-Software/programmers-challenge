## EMEA PUG Challenge: Programmer's Challenge

We have a server that plays games – specifically Othello (aka Reversi) - and it's bored and lonely.

You write some ABL code that plays Othello by talking to the server using a specific API we provide. During the PUG Challenge, players play games against each other in a tournament that consists of a knockout competition. Preliminary rounds will take place during the PUG Challenge and the final match will take place during a session on Friday at 3pm.

On top of your peers’ recognition, prizes will be offered by Riverside Software

### The Competition

Contestants should register themselves by emailing a player name to i-want-to-participate@pugchallenge.eu. This is required to be able to test and partipate in the contest. Your player name is also your team name. The challenge is open to anyone - even DBA's.

Entries **must** be written **completely** in ABL. Calling out to external non-ABL services is cheating. Submissions may be made until **17:00 local time on Thursday 16th November, 2017**. The knockout rounds will start shortly thereafter. The knockout brackets and scores will be displayed in a prominent location at the event.

Players will be randomly assigned a number once the submission deadline has passed, which will determine the starting pairs of games. If there is an uneven number of players, the lowest-numbered player will receive a bye.

For the initial round, the higher player number is assigned the dark tile. For subsequent rounds, the player with the highest points score is assigned dark; if scores are tied, the higher player number is assigned dark. The game board will be initially set such that the disks with dark side up are to the north-east and south-west (from both players' perspectives).

The player assigned the dark tile has the first turn.

Prizes will be given to the tournament winner and the scorer of the highest number of points.

The winner of a game is either the player with the most disks on the board, or in the event of a tie, the player with the highest score (including the current game's points). The organisers will run the contestants' code for the tournament on a game server.

Questions? Comments? Email us at i-want-to-participate@pugchallenge.eu

### Game server

The game server will be available for testing/dev purposes until submissions close. The URI for the game server is http://52.58.51.10:8080/ClientService.svc . This server will be used for the knockout games once submissions close; it will be flushed/refreshed/cleared before the tournament begins.

The game server requires a team and a player name to enter a game. Teams are created when players reqister; a team can play but any player name may be used for testing purposes. For the tournament only one entry per team is allowed (with any player name).

The API for interacting with the game server is described in [this document](pug_challenge_api.pdf).

A template ABL program is available in case you don't feel like writing the state machine yourself. Feel free to use and modify it as you see fit. The program works as long as you fill in
1. the values of the teamName, teamSecret and playerName variables, and
2. the algorithm in the CalculateMove internal procedure
3. and add the $DLC/[tty|gui]/netlib/OpenEdge.Net.pl library to your PROPATH.

### Testing

Contestants will be granted admin rights to allow them to start and manage games on the game server. These admin rights will be revoked at the start of the competition.

Please note that all contestants will share a single game server for testing - please play nicely with your fellow contestants.

More information about the running the Admin Client to allow testing is here .

## Contest rules

* Entries must be written in ABL
* Entries must be submitted in a zip file named <player>.zip . These must be emailed to challenge@pugchallenge.org
* The start program must be named othello.p and have no parameters (input or output).
* ABL code will run in 11.7.0
* Code will be run from a single PROPATH entry
* The competition will add the OpenEdge.Net.pl library for an HTTP client
* All ABL code should be self-contained and have no external dependencies (including OS dependencies). You can include any helper code you deem necessary


## The Game

The purpose of the game is to have a majority of the disks on the board once all legal moves are exhausted.

### Initial board

There are 4 disks on board at the start of the game: 2 white (light) and 2 black (dark) . The first move always belongs to dark/black.

[[img001.png]]

### Legal moves

Each move adds 1 disc to the board. By last move added disc and other same colors discs added before, should flank at least one opponent discs on vertical, horizontal or diagonal direction (between your discs one or more opponent discs appear). For example possible legal moves from starting position for dark (marked by red)

[[img002.png]]

All discs flanked by last move change their color. For example from start position dark chooses to move to Row 2 Col 4 (2;4). In that case the light disc placed on (3;4) becomes dark:

[[img003.png]]

Now it is light's turn and their legal moves are following:

[[img004.png]]

And so on.

### Pass situation

During game situation when one of opponents have no legal moves can appear. In that case a player must skip their move and opponent get possibility to move. In following situation light has no legal moves so they need to pass and dark are continues

[[img005.png]]

### End of game

Game is ongoing until board full or both opponents have no legal moves. Following picture represent board state with no legal moves for both opponents.

[[img006.png]]

The player that has the most disks on the board wins. In previous picture light wins since light has 27 disks and dark has 22.

### Game hints

* Remember that the goal is to have the most disks at when there are no more legal moves for either player
* A move which flips many of opponent disks is not necessarily a good one
* Taking the corner is a good move in general, since a disk in the corner can't be flipped (overtaken by opponent), but game target is not take all corners but have majority on the board
* It is possible to flip disks in as many as 8 directions at once (calculate precisely)
* There are plenty of strategies available online for playing Othello/Reversi

## Scoring

Points are cumulative during the competition.

|| Points || Rule ||
|| +3 || Three points for a win ||
|| +1 || Bonus point for a whitewash (ie if opponent left without disks on board) ||
|| +1 || One point for a draw (for each opponent) ||
|| +0 || Zero points for a loss or technical loss ||
|| -1 || One point deducted for a restart ||

"Disk difference" will be measured and only used as a tie-breaker (if two or more players have the same number of points)
1. The player with the biggest differential wins
2. If two players have the same differentials, the highest "for" disks wins
3. If there are still tied players, the winner will be determined by a best-of-three game of Rock-Paper-Scissors (or something similarly inane)