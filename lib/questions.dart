// questions.dart

/// Each truth/dare is a Map:
/// { "text": "Question or Dare text, possibly using {partner} placeholder",
///   "requiresPartner": bool }
///
/// The gameplay code has a scoring system:
///  - Truth = 1 point
///  - Dare = 2 points
///  - Skip = -1
///
/// And orientation matching logic in findCompatiblePartner()

// Orientation-based logic
bool arePlayersCompatible(
  Map<String, dynamic> p1,
  Map<String, dynamic> p2,
) {
  String sex1 = p1['sex'];
  String orient1 = p1['orientation'];
  String sex2 = p2['sex'];
  String orient2 = p2['orientation'];

  bool p1OK = checkCompatibilityOneWay(sex1, orient1, sex2);
  bool p2OK = checkCompatibilityOneWay(sex2, orient2, sex1);

  return p1OK && p2OK;
}

bool checkCompatibilityOneWay(String sex1, String orient1, String sex2) {
  if (orient1 == 'straight') {
    return sex1 != sex2; // must be opposite
  } else if (orient1 == 'gay') {
    return sex1 == sex2; // must be same
  } else if (orient1 == 'bisexual') {
    return true; // can be either
  }
  return false; // default if unknown
}

// Try to find a random partner
int findCompatiblePartner(int currentIndex, List<Map<String, dynamic>> allPlayers) {
  final currentPlayer = allPlayers[currentIndex];
  List<int> candidateIndices = List.generate(allPlayers.length, (i) => i)
    ..remove(currentIndex); // exclude self
  candidateIndices.shuffle();

  for (int candidateIndex in candidateIndices) {
    if (arePlayersCompatible(currentPlayer, allPlayers[candidateIndex])) {
      return candidateIndex; // first found match
    }
  }

  return -1; // no match found
}

/// TRUTHS
/// Adjust as needed
Map<int, List<Map<String, dynamic>>> truths = {
  1: [
    {
      "text": "What is your biggest fear?",
      "requiresPartner": false,
    },
    {
      "text": "Who was your first crush?",
      "requiresPartner": false,
    },
  ],
  2: [
    {
      "text": "What is your guilty pleasure?",
      "requiresPartner": false,
    },
    {
      "text": "What is your weirdest habit?",
      "requiresPartner": false,
    },
  ],
  3: [
    {
      "text": "What is the most embarrassing thing you’ve done?",
      "requiresPartner": false,
    },
    {
      "text": "Have you ever cheated on a test?",
      "requiresPartner": false,
    },
  ],
  4: [
    {
      "text": "What is your wildest fantasy?",
      "requiresPartner": false,
    },
    {
      "text": "Have you ever skinny-dipped?",
      "requiresPartner": false,
    },
  ],
  5: [
    {
      "text": "What secret have you kept from everyone?",
      "requiresPartner": false,
    },
    {
      "text": "What is something you still regret?",
      "requiresPartner": false,
    },
  ],
};

/// DARES
Map<int, List<Map<String, dynamic>>> dares = {
  1: [
    {
      "text": "Do 10 push-ups.",
      "requiresPartner": false,
    },
    {
      "text": "Sing your favorite song out loud.",
      "requiresPartner": false,
    },
  ],
  2: [
    {
      "text": "Dance like nobody’s watching for 30 seconds.",
      "requiresPartner": false,
    },
    {
      "text": "Impersonate another player for 1 minute.",
      "requiresPartner": false,
    },
  ],
  3: [
    {
      "text": "Let another player send a text from your phone.",
      "requiresPartner": true,
    },
    {
      "text": "Wear your clothes inside out for the rest of the round.",
      "requiresPartner": false,
    },
  ],
  4: [
    {
      "text": "Let {partner} draw on your face with a marker.",
      "requiresPartner": true,
    },
    {
      "text": "Do a dramatic reading of a romantic novel passage.",
      "requiresPartner": false,
    },
  ],
  5: [
    {
      "text": "Give {partner} your best 'sexy' dance.",
      "requiresPartner": true,
    },
    {
      "text": "Switch an item of clothing with {partner}.",
      "requiresPartner": true,
    },
  ],
};
