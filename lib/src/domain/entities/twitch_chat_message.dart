import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:irllink/src/domain/entities/settings.dart';
import 'package:irllink/src/domain/entities/twitch_badge.dart';
import 'package:collection/collection.dart';
import 'package:irllink/src/presentation/widgets/chat/cheer_emote.dart';
import 'package:irllink/src/presentation/widgets/chat/third_part_emote.dart';
import 'package:irllink/src/presentation/widgets/chat/twitch_emote.dart';
import 'package:irllink/src/presentation/widgets/chat/word.dart';
import 'package:uuid/uuid.dart';
import 'package:faker/faker.dart';
import 'emote.dart';

//ignore: must_be_immutable
class TwitchChatMessage extends Equatable {
  final String messageId;
  final List<TwitchBadge> badges;
  final String color;
  final String authorName;
  final String authorId;
  final Map<String, List> emotes;
  final String message;
  final List<Widget> messageWidgetsBuild;
  final int timestamp;
  final bool isBitDonation;
  final int bitAmount;
  final bool isAction;
  bool isDeleted;

  TwitchChatMessage({
    required this.messageId,
    required this.badges,
    required this.color,
    required this.authorName,
    required this.authorId,
    required this.emotes,
    required this.message,
    required this.messageWidgetsBuild,
    required this.timestamp,
    required this.isBitDonation,
    required this.bitAmount,
    required this.isAction,
    required this.isDeleted,
  });

  @override
  List<Object?> get props {
    return [
      messageId,
      badges,
      color,
      authorName,
      authorId,
      emotes,
      message,
      messageWidgetsBuild,
      timestamp,
      isBitDonation,
      bitAmount,
      isAction,
      isDeleted,
    ];
  }

  @override
  bool get stringify => true;

  factory TwitchChatMessage.randomGeneration() {
    Uuid uuid = Uuid();
    List<TwitchBadge> badges = [];
    String username = faker.internet.userName();
    String message = faker.lorem.sentence();
    Map emotesIdsPositions = {};
    List thirdPartEmotes = [];
    List cheerEmotes = [];
    bool isAction = false;
    String color = randomUsernameColor(username);
    bool isBitDonation = false;
    Settings settings = Settings.defaultSettings();

    List<Widget> messageWidgetsBuild = stringToWidgets(
      message,
      emotesIdsPositions,
      thirdPartEmotes,
      settings,
      isBitDonation,
      cheerEmotes,
      isAction,
      color,
    );
    return TwitchChatMessage(
      messageId: uuid.v4(),
      badges: badges,
      color: color,
      authorName: username,
      authorId: uuid.v4(),
      emotes: {},
      message: message,
      messageWidgetsBuild: messageWidgetsBuild,
      timestamp: faker.date
          .dateTime(minYear: 2000, maxYear: 2020)
          .microsecondsSinceEpoch,
      isBitDonation: isBitDonation,
      bitAmount: 0,
      isAction: isAction,
      isDeleted: false,
    );
  }

  factory TwitchChatMessage.fromString({
    required List<TwitchBadge> twitchBadges,
    required List<Emote> cheerEmotes,
    required List<Emote> thirdPartEmotes,
    required String message,
    required Settings settings,
  }) {
    final Map<String, String> messageMapped = {};

    //We split the message by ';' to get the different parts
    List messageSplited = message.split(';');
    //We split each part by '=' to get the key and the value
    messageSplited.forEach((element) {
      List elementSplited = element.split('=');
      messageMapped[elementSplited[0]] = elementSplited[1];
    });

    //We get the badges
    List<TwitchBadge> badges =
        getBadges(messageMapped['badges'].toString(), twitchBadges);

    //We get the color
    String color = messageMapped['color']!;
    //If the color is empty, we generate a random color
    if (color == "") {
      color = randomUsernameColor(messageMapped['display-name']!);
    }

    Map<String, List<List<String>>> emotesIdsPositions = {};
    List<String> tempEmoteList = [];
    //We get the emotes
    if (messageMapped['emotes'] != "") {
      //We check if there is multiple emotes
      bool multipleEmotes = messageMapped['emotes']!.contains('/');
      //If there is multiple emotes, we split them
      if (multipleEmotes) {
        tempEmoteList = messageMapped['emotes']!.split('/');
      } else {
        tempEmoteList = [messageMapped['emotes']!];
      }

      //We get the emotes positions
      tempEmoteList.forEach((element) {
        List<List<String>> positions = [];
        //We check if there is multiple positions for the same emote
        bool sameEmote = element.split(':')[1].toString().contains(',');
        //If there is multiple positions for the same emote, we split them
        if (sameEmote) {
          for (String position in element.split(':')[1].split(',')) {
            positions.add(position.split('-'));
          }
        } else {
          positions = [element.split(':')[1].split('-')];
        }

        //We add the emote id and the positions to the map
        emotesIdsPositions[element.split(':')[0]] = positions;
      });
    }

    //We check if the message is a bit donation
    bool isBitDonation = messageMapped['bits'] != null;

    //We get the message wrote by the user
    List messageList = messageSplited.last.split(':').sublist(2);
    String messageString = messageList.join(':');

    //We check if the message is an action (/me)
    bool isAction = messageString.startsWith("ACTION");
    if (isAction) {
      messageString = messageString
          .replaceFirst("ACTION", '')
          .replaceFirst("", '')
          .trim();
    }

    List<Widget> messageWidgetsBuild = stringToWidgets(
      messageString,
      emotesIdsPositions,
      thirdPartEmotes,
      settings,
      isBitDonation,
      cheerEmotes,
      isAction,
      color,
    );

    return TwitchChatMessage(
      messageId: messageMapped['id'] as String,
      badges: badges,
      color: color,
      authorName: messageMapped['display-name'] as String,
      authorId: messageMapped['user-id'] as String,
      emotes: emotesIdsPositions,
      message: messageString,
      messageWidgetsBuild: messageWidgetsBuild,
      timestamp: int.parse(messageMapped['tmi-sent-ts'] as String),
      isBitDonation: isBitDonation,
      bitAmount:
          messageMapped['bits'] == null ? 0 : int.parse(messageMapped['bits']!),
      isAction: isAction,
      isDeleted: false,
    );
  }
}

//We get the badges from the badges string
List<TwitchBadge> getBadges(
    String badgesString, List<TwitchBadge> twitchBadges) {
  List<TwitchBadge> badges = <TwitchBadge>[];
  //We split the badges string by ','
  List badgesSplited = badgesString.split(',');
  //We check if the badges string is not empty
  if (badgesSplited.isNotEmpty) {
    //We loop through the badges
    badgesSplited.forEach((i) {
      //We check if the badge is in the list of badges
      TwitchBadge? badgeFound = twitchBadges.firstWhereOrNull((badge) =>
          badge.setId == i.split('/')[0] && badge.versionId == i.split('/')[1]);
      //If the badge is in the list of badges
      if (badgeFound != null) {
        //We add the badge to the list
        badges.add(badgeFound);
      }
    });
  }
  return badges;
}

String randomUsernameColor(String username) {
  List<List<String>> defaultColors = [
    ["Red", "#FF0000"],
    ["Blue", "#0000FF"],
    ["Green", "#00FF00"],
    ["FireBrick", "#B22222"],
    ["Coral", "#FF7F50"],
    ["YellowGreen", "#9ACD32"],
    ["OrangeRed", "#FF4500"],
    ["SeaGreen", "#2E8B57"],
    ["GoldenRod", "#DAA520"],
    ["Chocolate", "#D2691E"],
    ["CadetBlue", "#5F9EA0"],
    ["DodgerBlue", "#1E90FF"],
    ["HotPink", "#FF69B4"],
    ["BlueViolet", "#8A2BE2"],
    ["SpringGreen", "#00FF7F"]
  ];

  var n = username.codeUnitAt(0) + username.codeUnitAt(username.length - 1);
  return defaultColors[n % defaultColors.length][1];
}

List<Widget> stringToWidgets(
  String messageString,
  Map emotesIdsPositions,
  List thirdPartEmotes,
  Settings settings,
  bool isBitDonation,
  List cheerEmotes,
  bool isAction,
  String color,
) {
  List<Widget> messageWidgetsBuild = [];

  for (int i = 0; i < messageString.trim().split(' ').length; i++) {
    String word = messageString.trim().split(' ')[i];

    MapEntry? emote = emotesIdsPositions.entries.firstWhereOrNull((element) =>
        element.value
            .where((position) =>
                messageString.substring(
                    int.parse(position[0]), int.parse(position[1]) + 1) ==
                word)
            .isNotEmpty);

    Emote? thirdPartyEmote =
        thirdPartEmotes.firstWhereOrNull((element) => element.name == word);
    bool isNextWordThirdPartEmoteZeroWidth = false;

    if (emote != null || thirdPartyEmote != null) {
      if (i < messageString.trim().split(' ').length - 1) {
        String nextWord = messageString.trim().split(' ')[i + 1];
        var zeroWidthEmote = thirdPartEmotes
            .firstWhereOrNull((element) => element.name == nextWord);
        isNextWordThirdPartEmoteZeroWidth =
            zeroWidthEmote?.isZeroWidth ?? false;

        if (isNextWordThirdPartEmoteZeroWidth) {
          messageWidgetsBuild.add(
            Stack(
              children: [
                emote != null
                    ? TwitchEmote(emote: emote)
                    : ThirdPartEmote(emote: thirdPartyEmote!),
                ThirdPartEmote(emote: thirdPartyEmote!),
              ],
            ),
          );
        }
      }
    }

    if (emote != null) {
      if (isNextWordThirdPartEmoteZeroWidth) continue;

      messageWidgetsBuild.add(
        Wrap(
          children: [
            TwitchEmote(emote: emote),
            Text(' '),
          ],
        ),
      );
    } else if (thirdPartyEmote != null && settings.isEmotes!) {
      if (isNextWordThirdPartEmoteZeroWidth) continue;

      if (thirdPartyEmote.isZeroWidth) {
        if (i > 0) {
          String previousWord = messageString.trim().split(' ')[i - 1];
          bool isPreviousWordEmote = emotesIdsPositions.entries
                  .firstWhereOrNull((element) => element.value
                      .where((position) =>
                          messageString.substring(int.parse(position[0]),
                              int.parse(position[1]) + 1) ==
                          previousWord)
                      .isNotEmpty) !=
              null;
          bool isPreviousWordThirdPartyEmote = thirdPartEmotes.firstWhereOrNull(
                  (element) => element.name == previousWord) !=
              null;
          if (isPreviousWordEmote || isPreviousWordThirdPartyEmote) continue;
        } else if (i != 0) continue;
      }

      messageWidgetsBuild.add(
        Wrap(
          children: [
            ThirdPartEmote(emote: thirdPartyEmote),
            Text(' '),
          ],
        ),
      );
    } else if (isBitDonation &&
        cheerEmotes.firstWhereOrNull((emote) => emote.name == word) != null) {
      messageWidgetsBuild.add(
        CheerEmote(
          cheerEmote:
              cheerEmotes.firstWhereOrNull((emote) => emote.name == word)!,
          textSize: settings.textSize!,
        ),
      );
    } else {
      messageWidgetsBuild.add(
        Word(
          word: word,
          isAction: isAction,
          color: color,
          textSize: settings.textSize!,
        ),
      );
    }
  }

  return messageWidgetsBuild;
}
