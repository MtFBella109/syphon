import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:syphon/domain/events/reactions/model.dart';
import 'package:syphon/global/libraries/redux/hooks.dart';
import 'package:syphon/domain/index.dart';
import 'package:syphon/global/dimensions.dart';

class ReactionRow extends HookWidget {
  final String currentUserId;
  final List<Reaction> reactions;
  final Function? onToggleReaction;

  const ReactionRow({
    super.key,
    this.reactions = const [],
    this.currentUserId = '',
    this.onToggleReaction,
  });

  @override
  Widget build(BuildContext context) {
    final reactionsMap = useRef(<String, int>{});
    final reactionsUserMap = useRef(<String, bool>{});

    final reactionKeys = reactionsMap.value.keys;
    final reactionCounts = reactionsMap.value.values;

    final currentUserId = useSelector<AppState, String>(
      (state) => state.authStore.currentUser.userId ?? '',
      '',
    );

    useEffect(() {
      for (final reaction in reactions) {
        reactionsMap.value.update(
          reaction.body ?? '',
          (value) => value + 1,
          ifAbsent: () => 1,
        );

        reactionsUserMap.value.update(
          reaction.body ?? '',
          (value) => value || reaction.sender == currentUserId,
          ifAbsent: () => reaction.sender == currentUserId,
        );
      }
    }, []);

    return ListView.builder(
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      itemCount: reactionKeys.length,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.antiAlias,
      itemBuilder: (BuildContext context, int index) {
        final reactionKey = reactionKeys.elementAt(index);
        final reactionCount = reactionCounts.elementAt(index);
        final isUserReaction = reactionsUserMap.value[reactionKey] ?? false;

        return GestureDetector(
          onTap: () => onToggleReaction?.call(reactionKey),
          child: Container(
            width: reactionCount > 1 ? 48 : 32,
            height: 48,
            decoration: BoxDecoration(
              color: isUserReaction
                  ? Theme.of(context).primaryColorDark
                  : Theme.of(context).dialogBackgroundColor,
              borderRadius: BorderRadius.circular(Dimensions.iconSize),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.light ? Colors.grey : Colors.white,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  reactionKey,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.titleMedium!.color,
                    height: 1.35,
                  ),
                ),
                Visibility(
                  visible: reactionCount > 1,
                  child: Container(
                    padding: EdgeInsets.only(left: 3),
                    child: Text(
                      reactionCount.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.titleMedium!.color,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
