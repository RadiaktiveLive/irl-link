import 'package:flutter/cupertino.dart';
import 'package:irllink/src/domain/entities/chat/twitch_chat_message.dart';

import '../emote.dart';
import '../settings.dart';
import '../twitch_badge.dart';

class RewardRedemptionEvent extends TwitchChatMessage {
  final String rewardId;

  RewardRedemptionEvent({
    required messageId,
    required badges,
    required color,
    required authorName,
    required authorId,
    required emotes,
    required message,
    required messageWidgetsBuild,
    required timestamp,
    required highlightType,
    required isAction,
    required isDeleted,
    required this.rewardId,
  }) : super(
    messageId: messageId,
    badges: badges,
    color: color,
    authorName: authorName,
    authorId: authorId,
    emotes: emotes,
    message: message,
    messageWidgetsBuild: messageWidgetsBuild,
    timestamp: timestamp,
    highlightType: highlightType,
    isAction: isAction,
    isDeleted: isDeleted,
  );

  factory RewardRedemptionEvent.fromString({
    required List<TwitchBadge> twitchBadges,
    required List<Emote> cheerEmotes,
    required List<Emote> thirdPartEmotes,
    required String message,
    required Settings settings,
  }) {
    final Map<String, String> messageMapped = {};

    List messageSplited = message.split(';');
    messageSplited.forEach((element) {
      List elementSplited = element.split('=');
      messageMapped[elementSplited[0]] = elementSplited[1];
    });

    String color = messageMapped['color']!;
    if (color == "") {
      color =
          TwitchChatMessage.randomUsernameColor(messageMapped['display-name']!);
    }

    Map<String, List<List<String>>> emotesIdsPositions =
    TwitchChatMessage.parseEmotes(messageMapped);

    List messageList = messageSplited.last.split(':').sublist(2);
    String messageString = messageList.join(':');

    List<Widget> messageInWidgets = TwitchChatMessage.messageToWidgets(
      messageString: messageString,
      emotesIdsPositions: emotesIdsPositions,
      thirdPartEmotes: thirdPartEmotes,
      settings: settings,
      highlightType: HighlightType.subscription,
      cheerEmotes: cheerEmotes,
      isAction: false,
      color: color,
    );

    return RewardRedemptionEvent(
      messageId: messageMapped['id'] as String,
      badges: TwitchChatMessage.getBadges(
          messageMapped['badges'].toString(), twitchBadges),
      color: color,
      authorName: messageMapped['display-name'] as String,
      authorId: messageMapped['user-id'] as String,
      emotes: emotesIdsPositions,
      message: messageString,
      messageWidgetsBuild: messageInWidgets,
      timestamp: int.parse(messageMapped['tmi-sent-ts'] as String),
      highlightType: HighlightType.subscription,
      isAction: false,
      isDeleted: false,
      rewardId: messageMapped['custom-reward-id'] as String,
    );
  }

  factory RewardRedemptionEvent.randomGeneration() {
    String message = "Finally got my 10000 points reward!";
    List<Widget> messageInWidgets = TwitchChatMessage.messageToWidgets(
      messageString: message,
      emotesIdsPositions: <String, List<List<String>>>{},
      thirdPartEmotes: <Emote>[],
      settings: Settings.defaultSettings(),
      highlightType: HighlightType.channelPointRedemption,
      cheerEmotes: <Emote>[],
      isAction: false,
      color: '#000000',
    );
    List badges = <TwitchBadge>[
      TwitchBadge(
        setId: 'sub-gifter',
        versionId: '1',
        imageUrl1x:
        'https://static-cdn.jtvnw.net/badges/v1/a5ef6c17-2e5b-4d8f-9b80-2779fd722414/1',
        imageUrl2x:
        'https://static-cdn.jtvnw.net/badges/v1/a5ef6c17-2e5b-4d8f-9b80-2779fd722414/2',
        imageUrl4x:
        'https://static-cdn.jtvnw.net/badges/v1/a5ef6c17-2e5b-4d8f-9b80-2779fd722414/3',
      ),
    ];
    return RewardRedemptionEvent(
      messageId: '123456789',
      badges: badges,
      color: TwitchChatMessage.randomUsernameColor('Lezd'),
      authorName: 'Lezd',
      authorId: '123456789',
      emotes: <String, List<dynamic>>{},
      message: message,
      messageWidgetsBuild: messageInWidgets,
      timestamp: 123456789,
      highlightType: HighlightType.channelPointRedemption,
      isAction: false,
      isDeleted: false,
      rewardId: '123456789',
    );
  }
}
