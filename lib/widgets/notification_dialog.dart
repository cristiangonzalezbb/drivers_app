import 'dart:async';

import 'package:drivers_app/global/global_var.dart';
import 'package:drivers_app/methods/common_methods.dart';
import 'package:drivers_app/models/trip_details.dart';
import 'package:drivers_app/pages/new_trip_page.dart';
import 'package:drivers_app/widgets/loading_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class NotificationDialog extends StatefulWidget {
  TripDetails? tripDetailsInfo;

  NotificationDialog({super.key, this.tripDetailsInfo,});

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog>
{
  String tripRequestStatus = "";
  CommonMethods cMethods = CommonMethods();

  cancelNotificationDialogAfter20Sec()
  {
    const oneTickPerSecond = Duration(seconds: 1);

    var timerCountDown = Timer.periodic(oneTickPerSecond, (timer)
    {
      driverTripRequestTimeout = driverTripRequestTimeout -1;
      if(tripRequestStatus == "accepted")
      {
        timer.cancel();
        driverTripRequestTimeout = 20;
      }

      if(driverTripRequestTimeout == 0)
      {
        Navigator.pop(context);
        timer.cancel();
        driverTripRequestTimeout = 20;
        audioPlayer.stop();
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    cancelNotificationDialogAfter20Sec();
  }

  checkAvailabilityOfTripRequest(BuildContext context) async
  {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => LoadingDialog(messageText: 'Please wait..',),
    );

    DatabaseReference driverTripStatusRef = FirebaseDatabase.instance.ref()
        .child("drivers")
        .child(FirebaseAuth.instance.currentUser!.uid)
        .child("newTripStatus");

    await driverTripStatusRef.once()
        .then((snap)
    {
      Navigator.pop(context);
      Navigator.pop(context);

      String newTripStatusValue = "";
      if(snap.snapshot.value != null)
      {
        newTripStatusValue = snap.snapshot.value.toString();
      }
      else
      {
        cMethods.displaySnackBar("Trip Request Not Found", context);
      }

      if(newTripStatusValue == widget.tripDetailsInfo!.tripID)
      {
        driverTripStatusRef.set("accepted");

        //disable homepage location updates
        cMethods.turnOffLocationUpdatesForHomePage();
        
        Navigator.push(context, MaterialPageRoute(
            builder: (c) =>
                NewTripPage(newTripDetailsInfo: widget.tripDetailsInfo)));
      }
      else if(newTripStatusValue == "cancelled")
      {
        cMethods.displaySnackBar("Trip Request has been Cancelled by user.", context);
      }
      else if(newTripStatusValue == "timeout")
      {
        cMethods.displaySnackBar("Trip Request timed out.", context);
      }
      else
      {
        cMethods.displaySnackBar("Trip Request removed. Not Found.", context);
      }
    });

  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: Colors.black54,
      child: Container(
        margin: const EdgeInsets.all(5),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 30.0,),

            Image.asset(
              "assets/images/uberexec.png",
              width: 140,
            ),

            const SizedBox(height: 16.0,),

            //title
            const Text(
              "NEW TRIP REQUEST",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20.0,),

            const Divider(
              height: 1,
              color: Colors.white,
              thickness: 1,
            ),

            const SizedBox(height: 10.0,),

            //pick - dropOff
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [

                  //pickup
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Image.asset(
                        "assets/images/initial.png",
                        height: 16,
                        width: 16,
                      ),

                      const SizedBox(height: 18,),

                      Expanded(
                          child: Text(
                            widget.tripDetailsInfo!.pickupAddress.toString(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 18,
                            ),
                          ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15,),

                  //dropOff
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Image.asset(
                        "assets/images/final.png",
                        height: 16,
                        width: 16,
                      ),

                      const SizedBox(height: 18,),

                      Expanded(
                        child: Text(
                          widget.tripDetailsInfo!.dropOffAddress.toString(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),

            const SizedBox(height: 20,),

            const Divider(
              height: 1,
              color: Colors.white,
              thickness: 1,
            ),

            const SizedBox(height: 8,),

            //decline btn - accept btn
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  Expanded(
                      child: ElevatedButton(
                        onPressed: ()
                        {
                          Navigator.pop(context);
                          audioPlayer.stop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                        ),
                        child: const Text(
                          "DECLINE",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ),

                  const SizedBox(height: 10,),

                  Expanded(
                      child: ElevatedButton(
                        onPressed: ()
                        {
                          audioPlayer.stop();

                          setState(() {
                            tripRequestStatus = "accepted";
                          });

                          checkAvailabilityOfTripRequest(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          "ACCEPT",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      )
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10.0,),

          ],

        ),
      ),
    );
  }
}
