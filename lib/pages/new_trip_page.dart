import 'dart:async';

import 'package:drivers_app/methods/common_methods.dart';
import 'package:drivers_app/widgets/loading_dialog.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../global/global_var.dart';
import '../methods/map_theme_methods.dart';
import '../models/trip_details.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NewTripPage extends StatefulWidget {
  TripDetails? newTripDetailsInfo;

  NewTripPage({super.key, this.newTripDetailsInfo,});

  @override
  State<NewTripPage> createState() => _NewTripPageState();
}

class _NewTripPageState extends State<NewTripPage>
{
  final Completer<GoogleMapController> googleMapCompleterController = Completer<GoogleMapController>();
  GoogleMapController? controllerGoogleMap;
  MapThemeMethods themeMethods = MapThemeMethods();
  double googleMapPaddingFromBottom = 0;
  List<LatLng> coordinatesPolyLineLatLngList = [];
  PolylinePoints polylinePoints = PolylinePoints();
  Set<Marker> markersSet = Set<Marker>();
  Set<Circle> circlesSet = Set<Circle>();
  Set<Polyline> polyLinesSet = Set<Polyline>();
  BitmapDescriptor? carMarkerIcon;
  bool directionRequested = false;
  String statusOfTrip = "accepted";
  String durationText = "";

  makeMarker()
  {
    if(carMarkerIcon == null)
    {
      ImageConfiguration configuration = createLocalImageConfiguration(context, size: Size(2, 2));
      BitmapDescriptor.fromAssetImage(configuration, "assets/images/tracking.png")
          .then((valueIcon)
      {
        carMarkerIcon = valueIcon;
      });
    }
  }

  obtainDirectionAndDrawRoute(sourceLocationLatLng, destinationLocationLatLng) async
  {
    showDialog(
      barrierDismissible: false,
      context: context, 
      builder: (BuildContext context) => LoadingDialog(messageText: "Please wait...",)
    );

    var tripDetailsInfo = await CommonMethods.getDirectionDetailsFromAPI(
        sourceLocationLatLng,
        destinationLocationLatLng
    );
    Navigator.pop(context);

    PolylinePoints pointsPolyline = PolylinePoints();
    List<PointLatLng> latLngPoints = pointsPolyline.decodePolyline(tripDetailsInfo!.encodedPoints!);

    coordinatesPolyLineLatLngList.clear();

    if(latLngPoints.isNotEmpty)
    {
      latLngPoints.forEach((PointLatLng pointLatLng)
      {
        coordinatesPolyLineLatLngList.add(LatLng(pointLatLng.latitude, pointLatLng.longitude));
      });
    }

    //draw polyline
    polyLinesSet.clear();

    setState(() {
      Polyline polyline = Polyline(
        polylineId: const PolylineId("routeID"),
        color: Colors.amber,
        points: coordinatesPolyLineLatLngList,
        jointType: JointType.round,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
      );
      polyLinesSet.add(polyline);
    });

    //fit the polyline on google map
    LatLngBounds boundsLatLng;

    if(sourceLocationLatLng.latitude > destinationLocationLatLng.latitude
      && sourceLocationLatLng.longitude > destinationLocationLatLng.longitude)
    {
      boundsLatLng = LatLngBounds(
          southwest: destinationLocationLatLng, 
          northeast: sourceLocationLatLng
      );
    }
    else if(sourceLocationLatLng.longitude > destinationLocationLatLng.longitude)
    {
      boundsLatLng = LatLngBounds(
          southwest: LatLng(sourceLocationLatLng.latitude, destinationLocationLatLng.longitude),
          northeast: LatLng(destinationLocationLatLng.latitude, sourceLocationLatLng.longitude),
      );
    }
    else if(sourceLocationLatLng.latitude > destinationLocationLatLng.latitude)
    {
      boundsLatLng = LatLngBounds(
        southwest: LatLng(destinationLocationLatLng.latitude, sourceLocationLatLng.longitude),
        northeast: LatLng(sourceLocationLatLng.latitude, destinationLocationLatLng.longitude),
      );
    }
    else
    {
      boundsLatLng = LatLngBounds(
        southwest: sourceLocationLatLng,
        northeast: destinationLocationLatLng,
      );
    }
    controllerGoogleMap!.animateCamera(CameraUpdate.newLatLngBounds(boundsLatLng, 72));

    //add marker
    Marker sourceMarker = Marker(
      markerId: const MarkerId('sourceID'),
      position: sourceLocationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    Marker destinationMarker = Marker(
      markerId: const MarkerId('destinationID'),
      position: destinationLocationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );

    setState(() {
      markersSet.add(sourceMarker);
      markersSet.add(destinationMarker);
    });

    //add circle
    Circle sourceCircle = Circle(
      circleId: const CircleId('sourceCircleID'),
      strokeColor: Colors.orange,
      strokeWidth: 4,
      radius: 14,
      center: sourceLocationLatLng,
      fillColor: Colors.green,
    );

    Circle destinationCircle = Circle(
      circleId: const CircleId('destinationCircleID'),
      strokeColor: Colors.green,
      strokeWidth: 4,
      radius: 14,
      center: destinationLocationLatLng,
      fillColor: Colors.orange,
    );

    setState(() {
      circlesSet.add(sourceCircle);
      circlesSet.add(destinationCircle);
    });
  }

  getLiveLocationUpdatesOfDriver()
  {
    LatLng lastPositionLatLng = LatLng(0, 0);

    positionsStreamNewPage = Geolocator.getPositionStream().listen((Position positionDriver)
    {
      driverCurrentPosition = positionDriver;

      LatLng driverCurrentPositionLatLng = LatLng(driverCurrentPosition!.latitude, driverCurrentPosition!.longitude);

      Marker carMarker = Marker(
        markerId: const MarkerId("carMarkerID"),
        position: driverCurrentPositionLatLng,
        icon: carMarkerIcon!,
        infoWindow: const InfoWindow(title: "My Location"),
      );
      setState(() {
        CameraPosition cameraPosition = CameraPosition(target: driverCurrentPositionLatLng, zoom: 16);
        controllerGoogleMap!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
        
        markersSet.retainWhere((element) => element.markerId.value == "carMarkerID");
        markersSet.add(carMarker);
      });
      lastPositionLatLng = driverCurrentPositionLatLng;

      //update Trip Details Information
      updateTripDetailsInformation();

      //update driver location to tripRequest
      Map updateLocationOfDriver =
      {
        "latitude": driverCurrentPositionLatLng!.latitude,
        "longitude": driverCurrentPositionLatLng!.longitude,
      };
      FirebaseDatabase.instance.ref().child("tripRequests")
          .child(widget.newTripDetailsInfo!.tripID!)
          .child("driverLocation")
          .set(updateLocationOfDriver);
    });
  }

  updateTripDetailsInformation() async
  {
    if(!directionRequested)
    {
      directionRequested = true;
      if(driverCurrentPosition == null)
      {
        return;
      }

      var driverLocationLatLng = LatLng(driverCurrentPosition!.longitude, driverCurrentPosition!.longitude);

      LatLng dropOffDestinationLocationLatLng;
      if(statusOfTrip == "accepted")
      {
        dropOffDestinationLocationLatLng = widget.newTripDetailsInfo!.pickUpLatLng!;
      }
      else
      {
        dropOffDestinationLocationLatLng = widget.newTripDetailsInfo!.dropOffLatLng!;
      }
      var directionDetailsInfo = await CommonMethods.getDirectionDetailsFromAPI(driverLocationLatLng, dropOffDestinationLocationLatLng);

      if(directionDetailsInfo != null)
      {
        directionRequested = false;
        setState(() {
          durationText = directionDetailsInfo.distanceTextString!;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    makeMarker();

    return Scaffold(
      body: Stack(
        children: [

          ///google map
          GoogleMap(
            padding: EdgeInsets.only(bottom: googleMapPaddingFromBottom),
            mapType: MapType.terrain,
            myLocationEnabled: true,
            markers: markersSet,
            circles: circlesSet,
            polylines: polyLinesSet,
            initialCameraPosition: googlePlexInitialPosition,
            onMapCreated: (GoogleMapController mapController) async
            {
              controllerGoogleMap = mapController;
              themeMethods.updateMapTheme(controllerGoogleMap!);
              googleMapCompleterController.complete(controllerGoogleMap);

              setState(() {
                googleMapPaddingFromBottom = 262;
              });

              var driverCurrentLocationLatLng = LatLng(
                  driverCurrentPosition!.latitude,
                  driverCurrentPosition!.longitude
              );

              var userPickUpLocationLatLng = widget.newTripDetailsInfo!.pickUpLatLng;

              await obtainDirectionAndDrawRoute(driverCurrentLocationLatLng, userPickUpLocationLatLng);

              getLiveLocationUpdatesOfDriver();
            },

          ),

          //trip details
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.only(topRight: Radius.circular(17), topLeft: Radius.circular(17)),
                boxShadow:
                [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 17,
                    spreadRadius: 0.5,
                    offset: Offset(0.7, 0.7),
                  )
                ],
              ),
              height: 282,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    //trip duration
                    Center(
                      child: Text(
                        durationText,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 5,),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        //user name
                        Text(
                          widget.newTripDetailsInfo!.userName!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: ()
                          {
                            launchUrl(
                              Uri.parse(
                                "tel://${widget.newTripDetailsInfo!.userPhone.toString()}"
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(
                              Icons.phone_android_outlined,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                      ],
                    ),


                  ],
                ),
              ),
            ),
          ),
          
        ],
      ),
    );
  }
}
