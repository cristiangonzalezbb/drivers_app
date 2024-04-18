import 'dart:async';
import 'dart:convert';

import 'package:drivers_app/methods/map_theme_methods.dart';
import 'package:drivers_app/pushNotification/push_notificacion_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../global/global_var.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> googleMapCompleterController = Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;
  Position? currentPositionOfDriver;
  Color colorToShow = Colors.green;
  String titleToShow = "GO ONLINE NOW";
  bool isDriverAvailable = false;
  DatabaseReference? newTripRequestReference;
  MapThemeMethods themeMethods = MapThemeMethods();

  getCurrentLiveLocationOfDriver() async
  {
    Position positionOfUsers = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
    currentPositionOfDriver = positionOfUsers;
    driverCurrentPosition = currentPositionOfDriver;

    LatLng positionOfUserInLatLng = LatLng(currentPositionOfDriver!.latitude, currentPositionOfDriver!.longitude);

    CameraPosition cameraPosition = CameraPosition(target: positionOfUserInLatLng, zoom: 19);
    controllerGoogleMap!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  goOnlineNow()
  {
    //all drivers who are Available for new trip request
    Geofire.initialize("onlineDrivers");

    Geofire.setLocation(
      FirebaseAuth.instance.currentUser!.uid,
      currentPositionOfDriver!.latitude,
      currentPositionOfDriver!.longitude,
    );

    newTripRequestReference = FirebaseDatabase.instance.ref()
        .child("drivers")
        .child(FirebaseAuth.instance.currentUser!.uid)
        .child("newTripStatus");
    newTripRequestReference!.set("waiting");

    newTripRequestReference!.onValue.listen((event) { });
  }

  setAndGetLocationUpdates()
  {
    positionsStreamHomePage = Geolocator.getPositionStream()
        .listen((Position position)
    {
      currentPositionOfDriver = position;

      if(isDriverAvailable == true)
      {
        Geofire.setLocation(
          FirebaseAuth.instance.currentUser!.uid,
          currentPositionOfDriver!.latitude,
          currentPositionOfDriver!.longitude,
        );
      }
      LatLng positionLatLng = LatLng(position.latitude, position.longitude);
      controllerGoogleMap!.animateCamera(CameraUpdate.newLatLng(positionLatLng));
    });
  }

  goOfflineNow()
  {
    //stop sharing driver live location updates
    Geofire.removeLocation(FirebaseAuth.instance.currentUser!.uid);

    //stop listening to the newTripStatus
    newTripRequestReference!.onDisconnect();
    newTripRequestReference!.remove();
    newTripRequestReference = null;
  }

  initializePushNotificationSystem()
  {
   PushNotificationSystem notificationSystem = PushNotificationSystem();
   notificationSystem.generateDeviceRegistrationToken();
   notificationSystem.startListeningForNewNotification(context);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    initializePushNotificationSystem();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          ///google map
          GoogleMap(
            padding: const EdgeInsets.only(top: 136),
            mapType: MapType.terrain,
            myLocationEnabled: true,
            initialCameraPosition: googlePlexInitialPosition,
            onMapCreated: (GoogleMapController mapController)
            {
              controllerGoogleMap = mapController;
              themeMethods.updateMapTheme(controllerGoogleMap!);

              googleMapCompleterController.complete(controllerGoogleMap);
              getCurrentLiveLocationOfDriver();
            },

          ),

          Container(
            height: 136,
            width: double.infinity,
            color: Colors.black54,
          ),

          //go online offline button
          Positioned(
            top: 61,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: ()
                  {
                    showModalBottomSheet(
                      context: context,
                      isDismissible: false,
                      builder: (BuildContext context)
                      {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey,
                                blurRadius: 5.0,
                                spreadRadius: 0.5,
                                offset: Offset(0.7, 0.7),
                              ),
                            ],
                          ),
                          height: 221,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            child: Column(
                              children: [
                                
                                const SizedBox(height: 11,),
                                Text(
                                    (!isDriverAvailable)
                                        ? "GO ONLINE NOW"
                                        : "GO OFFLINE NOW",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 21,),

                                Text(
                                  (!isDriverAvailable)
                                      ? "You are about to do online, you will become available to receive trip request from users."
                                      : "You are about to go offline, you will stop receiving new trip request from users.",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white30,
                                  ),
                                ),

                                const SizedBox(height: 21,),

                                Row(
                                  children: [
                                    Expanded(
                                        child: ElevatedButton(
                                          onPressed: ()
                                          {
                                              Navigator.pop(context);
                                          },
                                          child: const Text(
                                            "BACK"
                                          ),

                                        ),
                                    ),

                                    const SizedBox(width: 16,),

                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: ()
                                        {
                                          if(!isDriverAvailable){
                                            //go
                                            goOnlineNow();

                                            //get driver location updates
                                            setAndGetLocationUpdates();

                                            Navigator.pop(context);

                                            setState(() {
                                              colorToShow = Colors.pink;
                                              titleToShow = "GO OFFLINE NOW";
                                              isDriverAvailable = true;
                                            });
                                          }
                                          else{
                                            //go offlie
                                            goOfflineNow();

                                            Navigator.pop(context);

                                            setState(() {
                                              colorToShow = Colors.green;
                                              titleToShow = "GO ONLINE NOW";
                                              isDriverAvailable = false;
                                            });
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: (titleToShow == "GO ONLINE NOW")
                                              ? Colors.green
                                              : Colors.pink,
                                        ),
                                        child: const Text(
                                            "CONFIRM"
                                        ),

                                      ),
                                    ),

                                  ],

                                ),
                                
                              ],
                              
                            ),
                            
                          ),
                        );
                      }
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorToShow,
                  ),
                  child: Text(
                    titleToShow,
                  ),
                ),
                
              ],
            ),
          )
        ],
      ),
    );
  }
}

