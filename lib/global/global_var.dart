import 'dart:async';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

String userName = "";
String googleMapKey = "AIzaSyAZgKndF7yAI7rkP7Lcil3X44qE1adavaI";

const CameraPosition googlePlexInitialPosition = CameraPosition(
    target: LatLng(-33.39713, -70.79412),
    zoom: 19.151926040649414,
);

StreamSubscription<Position>? positionsStreamHomePage;
StreamSubscription<Position>? positionsStreamNewPage;

int driverTripRequestTimeout = 20;

final audioPlayer = AssetsAudioPlayer();

Position? driverCurrentPosition;