import 'package:flutter/material.dart';
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'question_loader.dart'; // loadPromptsFromCsv, PromptManager, etc.

// ---------------------------------------------------------
// GLOBALS / GAME STATE
// ---------------------------------------------------------
List<Map<String, dynamic>> players = [];
Map<int, bool> levelIsActive = {1:true, 2:true, 3:true, 4:true, 5:true};

int currentPlayerIndex = 0;
int currentLevel = 1;
String currentPrompt = '';
String currentPartnerName = '';
int playersAnsweredThisLevel = 0;

bool lastWasTruth = false;
bool lastWasDare = false;
bool lastWasWild = false;

// Timer logic
bool isTimedChallenge = false;
Timer? challengeTimer;
int timeLeft = 0;
bool timerStarted = false;

ConfettiController? globalConfettiController;
ConfettiController? globalEndGameConfettiController;

// Colors for categories
const Color truthColor = Color(0xFF1976D2); // a shade of blue
const Color dareColor  = Color(0xFFD32F2F); // a shade of red
const Color wildColor  = Color(0xFF388E3C); // a shade of green

// Colors for Complete / Skip
const Color completeColor = Color(0xFF00695C); 
const Color skipColor     = Color(0xFFB71C1C); 

// We'll color just the prompt container, not the entire screen
Color promptAreaColor = Colors.black54; // default until a category is chosen

// Big winner threshold
const int bigWinnerLead = 5;

// "Drink If" logic
bool drinkIfPerLevel = true;
late PromptManager promptManager;

// We'll track if a category is locked in (to disable the other 2 buttons)
bool categoryChosen = false;

// ---------------------------------------------------------
// MAIN APP
// ---------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final allPrompts = await loadPromptsFromCsv('assets/questions.csv');
  promptManager = PromptManager(allPrompts);
  runApp(UnveilApp());
}

class UnveilApp extends StatefulWidget {
  @override
  State<UnveilApp> createState() => _UnveilAppState();
}

class _UnveilAppState extends State<UnveilApp> {
  @override
  void initState() {
    super.initState();
    globalConfettiController = ConfettiController(duration: Duration(seconds: 1));
    globalEndGameConfettiController =
        ConfettiController(duration: Duration(seconds: 3));
  }

  @override
  void dispose() {
    globalConfettiController?.dispose();
    globalEndGameConfettiController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unveil',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.purple,
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => TitleScreen(),
        '/managePlayers': (ctx) => ManagePlayersScreen(),
        '/settings': (ctx) => SettingsScreen(),
        '/instructions': (ctx) => InstructionsScreen(), // instructions
        '/gameplay': (ctx) => GameplayScreen(),
        '/finalScores': (ctx) => FinalScoresScreen(),
      },
    );
  }
}

// ---------------------------------------------------------
// TITLE SCREEN
// ---------------------------------------------------------
class TitleScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade900, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: IconButton(
                icon: Icon(Icons.settings, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                tooltip: 'Settings',
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(Icons.person, color: Colors.white),
                onPressed: () => Navigator.pushNamed(context, '/managePlayers'),
                tooltip: 'Manage Players',
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Unveil',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ready to bare your soul... or your body?',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      if (players.isEmpty) {
                        Navigator.pushNamed(context, '/managePlayers');
                      } else {
                        _initGame();
                        Navigator.pushNamed(context, '/gameplay');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text('Start Game'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/instructions');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: Text('Instructions'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _initGame() {
  currentPlayerIndex = 0;
  currentPrompt = '';
  currentPartnerName = '';
  playersAnsweredThisLevel = 0;
  currentLevel = _findFirstActiveLevel();

  // Reset scores
  for (var p in players) {
    p['score'] = 0;
  }

  lastWasTruth = false;
  lastWasDare = false;
  lastWasWild = false;
  isTimedChallenge = false;
  timeLeft = 0;
  timerStarted = false;

  promptAreaColor = Colors.black54; 
  categoryChosen = false;
}

int _findFirstActiveLevel() {
  for (int lvl = 1; lvl <= 5; lvl++) {
    if (levelIsActive[lvl] == true) {
      return lvl;
    }
  }
  return 1;
}

// ---------------------------------------------------------
// MANAGE PLAYERS SCREEN
// ---------------------------------------------------------
class ManagePlayersScreen extends StatefulWidget {
  @override
  _ManagePlayersScreenState createState() => _ManagePlayersScreenState();
}

class _ManagePlayersScreenState extends State<ManagePlayersScreen> {
  final TextEditingController _playerNameController = TextEditingController();

  final List<String> _sexOptions = ['male', 'female', 'non-binary'];
  final List<String> _orientationOptions = ['straight', 'gay', 'bisexual'];

  String _selectedSex = 'male';
  String _selectedOrientation = 'straight';
  bool _exitedOnce = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_exitedOnce && players.isNotEmpty) {
          _exitedOnce = true;
          bool goToGame = await _askGoToGame(context);
          if (goToGame) {
            _initGame();
            Navigator.pushReplacementNamed(context, '/gameplay');
          } else {
            Navigator.pop(context);
          }
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Manage Players'),
          backgroundColor: Colors.purple,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _playerNameController,
                    decoration: InputDecoration(
                      labelText: 'Player Name',
                      suffixIcon: IconButton(
                        icon: Icon(Icons.add),
                        onPressed: _addPlayer,
                      ),
                    ),
                    onSubmitted: (_) => _addPlayer(),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text("Sex: "),
                      SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedSex,
                        dropdownColor: Colors.grey[900],
                        items: _sexOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedSex = newValue ?? 'male';
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text("Orientation: "),
                      SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedOrientation,
                        dropdownColor: Colors.grey[900],
                        items: _orientationOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedOrientation = newValue ?? 'straight';
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.grey[850],
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(players[index]['name']),
                          subtitle: Text(
                            'Sex: ${players[index]['sex']} '
                            '| Orientation: ${players[index]['orientation']} '
                            '| Score: ${players[index]['score']}',
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removePlayer(index),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // hidden double tap
            Positioned(
              bottom: 10,
              right: 10,
              child: GestureDetector(
                onDoubleTap: _populateTestPlayers,
                child: Container(
                  width: 30,
                  height: 30,
                  color: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addPlayer() {
    String name = _playerNameController.text.trim();
    if (name.isNotEmpty) {
      bool exists = players.any(
          (p) => p['name'].toString().toLowerCase() == name.toLowerCase());
      if (!exists) {
        setState(() {
          players.add({
            "name": name,
            "sex": _selectedSex,
            "orientation": _selectedOrientation,
            "score": 0,
          });
        });
      }
      _playerNameController.clear();
    }
  }

  void _removePlayer(int index) {
    setState(() {
      players.removeAt(index);
    });
  }

  Future<bool> _askGoToGame(BuildContext context) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text("Ready to Start?"),
              content: Text("You have some players. Jump right into the game?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text("Not yet"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text("Yes, let's go!"),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  void _populateTestPlayers() {
    setState(() {
      players.clear();
      players.addAll([
        {"name": "Alice", "sex": "female", "orientation": "straight", "score": 0},
        {"name": "Bob", "sex": "male", "orientation": "gay", "score": 0},
        {"name": "Charlie", "sex": "male", "orientation": "bisexual", "score": 0},
        {"name": "Dana", "sex": "female", "orientation": "bisexual", "score": 0},
      ]);
    });
  }
}

// ---------------------------------------------------------
// SETTINGS SCREEN
// ---------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: Colors.purple,
      ),
      body: ListView(
        children: [
          for (int lvl in [1,2,3,4,5])
            ListTile(
              title: Text('Level $lvl'),
              trailing: Switch(
                value: levelIsActive[lvl]!,
                onChanged: (val) {
                  setState(() {
                    levelIsActive[lvl] = val;
                  });
                },
              ),
            ),
          Divider(),
          ListTile(
            title: Text('“Drink If…” Frequency'),
            subtitle: Text(drinkIfPerLevel ? 'Once per level' : 'Once per round'),
            trailing: Switch(
              value: drinkIfPerLevel,
              onChanged: (val) {
                setState(() {
                  drinkIfPerLevel = val;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// INSTRUCTIONS SCREEN (EXPANDED)
// ---------------------------------------------------------
class InstructionsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Instructions'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                "How to Play Unveil",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
              ),
              SizedBox(height: 16),
              Text(
                "1. Manage Players: Add or remove players in the Manage Players screen.\n"
                "2. Level Toggling: In Settings, enable or disable each level (1..5). Higher levels are more risqué.\n"
                "3. Starting the Game: Once you have players, press 'Start Game' on the title screen.\n\n"

                "What Are 'Truth', 'Dare', and 'Wild'?\n"
                "• Truth: Answer a personal question honestly. Usually 1 point × level.\n"
                "• Dare: Perform an action or challenge. Usually 2 points × level.\n"
                "• Wild: A group or unusual scenario that can be surprising or comedic—often 2 points × level.\n"
                "  For instance, multiple participants might get involved.\n\n"

                "During Gameplay:\n"
                "• The current player chooses a category (Truth, Dare, or Wild).\n"
                "• The prompt appears with a color-coded background:\n"
                "   - Truth = Blue, Dare = Red, Wild = Green.\n"
                "• Other category buttons are disabled until the player completes or skips.\n\n"

                "Timer & Scoring:\n"
                "• Some prompts are timed. Tap 'Start Timer' to begin the countdown.\n"
                "• If you run out of time, that’s an automatic skip (-1 point).\n"
                "• Completing a Truth = 1 × level points, Dare or Wild = 2 × level.\n"
                "• Skipping any prompt = -1 point.\n\n"

                "Partner Prompts:\n"
                "• If a prompt requires a partner, the game picks someone compatible.\n"
                "• Partner is shown in bold, so it’s easy to see who’s involved.\n\n"

                "Passing the Turn:\n"
                "• Once you complete or skip, it moves to the next player.\n"
                "• After everyone in a level has gone, the game may automatically advance to the next level.\n"
                "• If ‘Drink If…’ is enabled, you’ll see a short prompt to have a sip.\n\n"

                "Big Winner:\n"
                "• If one player leads by 5+ points over the second place, a pop-up will announce they are 'dominating.'\n\n"

                "Ending the Game:\n"
                "• The game ends when you’ve exhausted all levels or when you press 'End Game'.\n"
                "• The Final Scores screen will list all players in descending order.\n\n"

                "Enjoy responsibly—be mindful, respect boundaries, and keep it fun!",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text("Back"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// GAMEPLAY SCREEN
// ---------------------------------------------------------
class GameplayScreen extends StatefulWidget {
  @override
  _GameplayScreenState createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late ConfettiController localConfetti;

  @override
  void initState() {
    super.initState();
    if (players.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
    }
    localConfetti = ConfettiController(duration: Duration(seconds: 1));
  }

  @override
  void dispose() {
    localConfetti.dispose();
    challengeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Scaffold(
        body: Center(child: Text("No players found. Please go back.")),
      );
    }

    // Sort scoreboard descending
    final sortedPlayers = List.from(players);
    sortedPlayers.sort((a, b) => b['score'].compareTo(a['score']));

    final currentPlayer = players[currentPlayerIndex];
    String cPlayerName = '${currentPlayer["name"]} (${currentPlayer["sex"]}, ${currentPlayer["orientation"]})';

    return Scaffold(
      appBar: AppBar(
        title: Text('Unveil - Level $currentLevel'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: Icon(Icons.fast_forward),
            onPressed: _skipLevel,
            tooltip: 'Skip This Level',
          ),
          IconButton(
            icon: Icon(Icons.stop_circle_outlined),
            onPressed: _endGameNow,
            tooltip: 'End Game',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.black, // main background
            child: ConfettiWidget(
              confettiController: localConfetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
            ),
          ),
          Column(
            children: [
              // Scoreboard row
              Container(
                height: 40,
                color: Colors.black54,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: sortedPlayers.map<Widget>((p) {
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${p["name"]} (${p["score"]})',
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Main area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Current / Next players stacked
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current player bold
                          Text(
                            'Current: $cPlayerName',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white70
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Next: ${_getNextPlayerInfo()}',
                            style: TextStyle(
                              fontSize: 14, 
                              fontStyle: FontStyle.italic, 
                              color: Colors.white60
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),

                      // Timer
                      if (isTimedChallenge) _buildTimerUI(),
                      SizedBox(height: 10),

                      // Category buttons row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCategoryButton('Truth', truthColor, !categoryChosen),
                          _buildCategoryButton('Dare', dareColor, !categoryChosen),
                          _buildCategoryButton('Wild', wildColor, !categoryChosen),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Prompt container with color
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: promptAreaColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            currentPrompt,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.white70),
                          ),
                        ),
                      ),

                      if (currentPartnerName.isNotEmpty) ...[
                        SizedBox(height: 10),
                        Text(
                          'Partner: $currentPartnerName',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold, // bold like current player
                            color: Colors.white70
                          ),
                        ),
                      ],
                      SizedBox(height: 20),

                      if (currentPrompt.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _nextTurn(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: completeColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: Text('Complete'),
                            ),
                            SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () => _nextTurn(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: skipColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              child: Text('Skip'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getNextPlayerInfo() {
    int nextIndex = (currentPlayerIndex + 1) % players.length;
    final np = players[nextIndex];
    return '${np["name"]} (${np["sex"]}, ${np["orientation"]})';
  }

  Widget _buildTimerUI() {
    return Column(
      children: [
        if (!timerStarted)
          ElevatedButton(
            onPressed: _startChallengeTimer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: Text('Start Timer'),
          ),
        if (timerStarted)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Time Left: $timeLeft s',
                style: TextStyle(fontSize: 18, color: Colors.redAccent),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _restartTimer,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                child: Text("Restart"),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCategoryButton(String cat, Color color, bool enabled) {
    return ElevatedButton(
      onPressed: enabled ? () => _selectCategory(cat) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      child: Text(cat),
    );
  }

  void _selectCategory(String category) {
    setState(() {
      categoryChosen = true;
    });

    if (category == 'Truth') {
      lastWasTruth = true; 
      lastWasDare = false; 
      lastWasWild = false;
      promptAreaColor = truthColor;
    } else if (category == 'Dare') {
      lastWasTruth = false; 
      lastWasDare = true; 
      lastWasWild = false;
      promptAreaColor = dareColor;
    } else {
      lastWasTruth = false; 
      lastWasDare = false; 
      lastWasWild = true;
      promptAreaColor = wildColor;
    }

    final isActive = levelIsActive[currentLevel] ?? false;
    if (!isActive) {
      setState(() {
        currentPrompt = "No prompts at level $currentLevel. Try skip or end game.";
        currentPartnerName = '';
        isTimedChallenge = false;
        timeLeft = 0;
        timerStarted = false;
      });
      return;
    }

    final prompt = promptManager.getRandomPrompt(category, currentLevel, players);
    if (prompt == null) {
      setState(() {
        currentPrompt = "No valid prompt found for $category at level $currentLevel.";
        currentPartnerName = '';
        isTimedChallenge = false;
        timeLeft = 0;
        timerStarted = false;
      });
    } else {
      _processPrompt(prompt);
    }
  }

  void _processPrompt(Prompt p) {
    isTimedChallenge = p.timed;
    timeLeft = p.timerSeconds;
    timerStarted = false;

    if (p.requiresPartner) {
      int partnerIndex = findCompatiblePartner(currentPlayerIndex, players);
      if (partnerIndex == -1) {
        setState(() {
          currentPrompt = "No compatible partner found. Try skip.";
          currentPartnerName = '';
          isTimedChallenge = false;
        });
        return;
      } else {
        final partnerName = players[partnerIndex]['name'];
        final replaced = p.promptText.replaceAll('{partner}', partnerName);
        setState(() {
          currentPrompt = replaced;
          currentPartnerName = partnerName;
        });
      }
    } else {
      setState(() {
        currentPrompt = p.promptText;
        currentPartnerName = '';
      });
    }
  }

  void _startChallengeTimer() {
    if (timeLeft <= 0) return;
    setState(() {
      timerStarted = true;
    });
    challengeTimer?.cancel();
    challengeTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        timeLeft--;
        if (timeLeft <= 0) {
          timer.cancel();
          // auto skip
          _nextTurn(false);
        }
      });
    });
  }

  void _restartTimer() {
    challengeTimer?.cancel();
    setState(() {
      timerStarted = false;
    });
  }

  void _nextTurn(bool completed) {
    challengeTimer?.cancel();
    challengeTimer = null;

    setState(() {
      categoryChosen = false;
    });

    if (completed) {
      localConfetti.play();
    }
    if (!completed) {
      players[currentPlayerIndex]['score'] -= 1;
    } else {
      int basePoints = 0;
      if (lastWasTruth) basePoints = 1;
      if (lastWasDare) basePoints = 2;
      if (lastWasWild) basePoints = 2;
      players[currentPlayerIndex]['score'] += (basePoints * currentLevel);
      _checkBigWinnerIntermission();
    }

    playersAnsweredThisLevel++;
    bool endOfLevel = (playersAnsweredThisLevel >= players.length);

    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;

    if (endOfLevel) {
      playersAnsweredThisLevel = 0;
      _showDrinkIfIfWanted();
      int nextLvl = _findNextActiveLevel(currentLevel);
      if (nextLvl == -1) {
        Navigator.pushReplacementNamed(context, '/finalScores');
        return;
      } else {
        currentLevel = nextLvl;
      }
    } else {
      if (!drinkIfPerLevel) {
        _showDrinkIfIfWanted();
      }
    }

    setState(() {
      currentPrompt = '';
      currentPartnerName = '';
      isTimedChallenge = false;
      timeLeft = 0;
      timerStarted = false;
      promptAreaColor = Colors.black54; // reset
    });
  }

  int _findNextActiveLevel(int thisLevel) {
    for (int lvl = thisLevel + 1; lvl <= 5; lvl++) {
      if (levelIsActive[lvl] == true) return lvl;
    }
    return -1;
  }

  void _showDrinkIfIfWanted() {
    final di = promptManager.getRandomDrinkIf();
    if (di == null) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Drink If..."),
          content: Text(di.promptText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text("OK"),
            )
          ],
        );
      },
    );
  }

  void _checkBigWinnerIntermission() {
    final sorted = List.from(players);
    sorted.sort((a, b) => b['score'].compareTo(a['score']));
    if (sorted.length >= 2) {
      final lead = sorted[0]['score'] - sorted[1]['score'];
      if (lead >= bigWinnerLead) {
        final name = sorted[0]['name'];
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text("$name is dominating!"),
              content: Text("They are $lead points ahead! Can anyone catch up?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text("We'll see!"),
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _skipLevel() {
    playersAnsweredThisLevel = 0;
    int nextLvl = _findNextActiveLevel(currentLevel);
    if (nextLvl == -1) {
      Navigator.pushReplacementNamed(context, '/finalScores');
      return;
    }
    currentLevel = nextLvl;
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    setState(() {
      currentPrompt = '';
      currentPartnerName = '';
      isTimedChallenge = false;
      timeLeft = 0;
      timerStarted = false;
      categoryChosen = false;
      promptAreaColor = Colors.black54;
    });
  }

  void _endGameNow() {
    Navigator.pushReplacementNamed(context, '/finalScores');
  }
}

// ---------------------------------------------------------
// FINAL SCORES SCREEN
// ---------------------------------------------------------
class FinalScoresScreen extends StatefulWidget {
  @override
  State<FinalScoresScreen> createState() => _FinalScoresScreenState();
}

class _FinalScoresScreenState extends State<FinalScoresScreen> {
  late ConfettiController endConfetti;

  @override
  void initState() {
    super.initState();
    endConfetti = ConfettiController(duration: Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      endConfetti.play();
    });
  }

  @override
  void dispose() {
    endConfetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List.from(players);
    sorted.sort((a, b) => b['score'].compareTo(a['score']));
    int highestScore = sorted.isNotEmpty ? sorted.first['score'] : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Final Scores'),
        backgroundColor: Colors.purple,
      ),
      body: Stack(
        children: [
          ConfettiWidget(
            confettiController: endConfetti,
            blastDirectionality: BlastDirectionality.explosive,
            maxBlastForce: 30,
            minBlastForce: 10,
            emissionFrequency: 0.05,
            numberOfParticles: 40,
            gravity: 0.1,
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Game Over!',
                  style: TextStyle(fontSize: 32, color: Colors.purpleAccent),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      bool isWinner = sorted[index]['score'] == highestScore;
                      return ListTile(
                        title: Text(
                          '${sorted[index]['name']}',
                          style: TextStyle(
                            fontSize: 20,
                            color: isWinner ? Colors.greenAccent : Colors.white,
                            fontWeight:
                                isWinner ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          '${sorted[index]['score']}',
                          style: TextStyle(fontSize: 20),
                        ),
                      );
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Text('Return to Main Menu'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
