import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:async/async.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:octo_image/octo_image.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contributor.dart';

final _contributorsProvider = StateProvider<List<Contributor>?>((_) => null);
final _indexProvider = StateProvider<IntHistory>((_) => IntHistory(0, 0));

class ContributorsWall extends StatefulWidget {
  @override
  _ContributorsWallState createState() => _ContributorsWallState();
}

class _ContributorsWallState extends State<ContributorsWall> {
  final client = http.Client();
  final r = Random();
  final cache = DefaultCacheManager();

  static const String token = String.fromEnvironment('API_TOKEN');

  Future<void> fetchContributors() async {
    var page = 0;
    final contributors = <Contributor>[];
    while (true) {
      print('Fetching page $page');
      final uri = Uri.parse(
          'https://api.github.com/repos/flutter/flutter/contributors?page=$page');
      final r = await client.get(uri,
          headers: {if (token.isNotEmpty) 'Authorization': 'token $token'});
      try {
        final list = jsonDecode(r.body) as List;
        if (list.isEmpty) break;
        final contribs = list
            .map((dynamic e) => Contributor.fromJson(e as Map<String, dynamic>))
            .toList();
        contributors.addAll(contribs);
      } catch (e, s) {
        debugPrintStack(stackTrace: s, label: e.toString());
        break;
      }
      page++;
    }
    context.read(_contributorsProvider).state = contributors;
    await nextContributor();
  }

  bool _auto = true;

  late final timer = RestartableTimer(Duration(seconds: 5), nextContributor)
    ..cancel();

  @override
  void initState() {
    super.initState();
    fetchContributors();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contributors showcase'),
      ),
      body: Consumer(
        builder: (context, w, child) {
          final contribsState = w(_contributorsProvider);
          final indexState = w(_indexProvider);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Time left until Flutter Engage',
                      style: Theme.of(context).textTheme.headline6,
                    ),
                    EngageCountDown(),
                  ],
                ),
              ),
              if (contribsState.state == null)
                Expanded(
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.headline6!,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator.adaptive(),
                        SizedBox(height: 32),
                        Text('Fetching all the amazing contributors\' data'),
                        SizedBox(height: 16),
                        Text('Hang tight...'),
                      ],
                    ),
                  ),
                )
              else
                ...buildExpanded(contribsState, indexState),
              SwitchListTile.adaptive(
                value: _auto,
                title: Text('Automatic playback'),
                onChanged: (v) {
                  setState(() {
                    _auto = v;
                  });
                  if (v) {
                    timer.reset();
                  } else {
                    timer.cancel();
                  }
                },
              )
            ],
          );
        },
      ),
    );
  }

  Future<void> nextContributor() async {
    if (_auto) timer.reset();
    var stateController = context.read(_contributorsProvider);
    var indexController = context.read(_indexProvider);
    var nextInt = r.nextInt(stateController.state?.length ?? 1);
    indexController.state = IntHistory(indexController.state.next, nextInt);
    var contributor = stateController.state![nextInt];
    await cache.getSingleFile(contributor.avatarUrl);
    print('Precached image for ${contributor.login}');
  }

  List<Widget> buildExpanded(StateController<List<Contributor>?> contribsState,
      StateController<IntHistory> indexState) {
    final c = contribsState.state![indexState.state.current];
    return [
      Expanded(
        flex: 5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                right: 16,
                left: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 256, maxWidth: 256),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ContributorWidget(c),
                ),
              ),
            ),
            SizedBox(height: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '@${c.login}',
                  style: Theme.of(context)
                      .textTheme
                      .headline6!
                      .apply(fontSizeFactor: 1.5),
                ),
                Text(
                  "${c.contributions} contributions",
                  style: Theme.of(context)
                      .textTheme
                      .subtitle2!
                      .apply(fontSizeFactor: 1.5),
                ),
              ],
            ),
          ],
        ),
      ),
      SizedBox(height: 16),
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                primary: Colors.black,
                padding: EdgeInsets.all(16),
                shape: StadiumBorder(),
              ),
              onPressed: () => launch(c.htmlUrl),
              label: Text('View on Github'),
              icon: Image.asset(
                'assets/gh-64.png',
                width: 32,
                height: 32,
              ),
            ),
            SizedBox(width: 32),
            TextButton(
              onPressed: contribsState.state == null ? null : nextContributor,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Next →", style: TextStyle(fontSize: 24)),
              ),
            ),
          ],
        ),
      )
    ];
  }
}

class EngageCountDown extends StatefulWidget {
  @override
  _EngageCountDownState createState() => _EngageCountDownState();
}

class _EngageCountDownState extends State<EngageCountDown>
    with SingleTickerProviderStateMixin {
  final engage = DateTime.utc(2021, 3, 3, 17, 30);
  Duration duration = Duration.zero;

  Duration? start;

  late final Timer ticker;

  @override
  void initState() {
    super.initState();
    start ??= engage.difference(DateTime.now().toUtc());

    var dur = Duration(milliseconds: 500);
    ticker = Timer.periodic(dur, (t) {
      final d = start! - dur * t.tick;
      if (mounted)
        setState(() {
          duration = d;
        });
    });
  }

  @override
  void dispose() {
    ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${duration.inHours}:${(duration.inMinutes % Duration.minutesPerHour).toString().padLeft(2, '0')}:${(duration.inSeconds % Duration.secondsPerMinute).toString().padLeft(2, '0')}',
      style: Theme.of(context).textTheme.headline4,
    );
  }
}

class ContributorWidget extends StatefulWidget {
  const ContributorWidget(
    this.c, {
    Key? key,
  }) : super(key: key);

  final Contributor c;

  @override
  _ContributorWidgetState createState() => _ContributorWidgetState();
}

class _ContributorWidgetState extends State<ContributorWidget> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launch(widget.c.htmlUrl),
      customBorder: CircleBorder(),
      child: OctoImage(
        image: CachedNetworkImageProvider(
          widget.c.avatarUrl,
          cacheManager: DefaultCacheManager(),
        ),
        imageBuilder: OctoImageTransformer.circleAvatar(),
        fit: BoxFit.contain,
        progressIndicatorBuilder: (context, progress) => SizedBox(),
      ),
    );
  }
}
