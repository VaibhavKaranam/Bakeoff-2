import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import ddf.minim.signals.*;
import ddf.minim.spi.*;
import ddf.minim.ugens.*;

import java.util.ArrayList;
import java.util.Collections;
import ddf.minim.*; // Need to install (Minim) library on sketch in order to work -> Click Sketch, Import Library, Search Minim 


//these are variables you should probably leave alone
int index = 0; //starts at zero-ith trial
float border = 0; //some padding from the sides of window, set later
int trialCount = 12; //this will be set higher for the bakeoff
int trialIndex = 0; //what trial are we on
int errorCount = 0;  //used to keep track of errors
float errorPenalty = 0.5f; //for every error, add this value to mean time
int startTime = 0; // time starts when the first click is captured
int finishTime = 0; //records the time of the final click
boolean userDone = false; //is the user done

boolean isDrawing = false; // Track if we're currently drawing a square
float startX, startY; // Starting point of the diagonal
float currentX, currentY; // Current point for dynamic drawing

final float screenPPI = 140; //what is the DPI of the screen you are using
//you can test this by drawing a 72x72 pixel rectangle in code, and then confirming with a ruler it is 1x1 inch. 

//These variables are for my example design. Your input code should modify/replace these!
float logoX = 500;
float logoY = 500;
float logoZ = 50f;
float logoRotation = 0;
AudioPlayer successSound;
AudioPlayer errorSound;

Minim minim;

private class Destination
{
  float x = 0;
  float y = 0;
  float rotation = 0;
  float z = 0;
}

ArrayList<Destination> destinations = new ArrayList<Destination>();

void setup() {
  size(1000, 800);  
  rectMode(CORNERS);
  textFont(createFont("Arial", inchToPix(.3f))); //sets the font to Arial that is 0.3" tall
  textAlign(CENTER);
  rectMode(CENTER); //draw rectangles not from upper left, but from the center outwards
  
  minim = new Minim(this);
  successSound = minim.loadFile("hit_sound.mp3");
  errorSound = minim.loadFile("error.mp3");
  
  //don't change this! 
  border = inchToPix(1f); //padding of 1.0 inches

  for (int i=0; i<trialCount; i++) //don't change this! 
  {
    Destination d = new Destination();
    d.x = random(border, width-border); //set a random x with some padding
    d.y = random(border, height-border); //set a random y with some padding
    d.rotation = random(0, 360); //random rotation between 0 and 360
    d.z = inchToPix((float)random(1,12)/4.0f); //increasing size from 0.25" up to 3.0" 
    destinations.add(d);
    println("created target with " + d.x + "," + d.y + "," + d.rotation + "," + d.z);
  }

  Collections.shuffle(destinations); // randomize the order of the button; don't change this.
}

void draw() {
  background(40); //background is dark grey
  noStroke();
  fill(255,0,0);
  
  fill(200);
  
  if (isDrawing) {
    float sideLength = dist(startX, startY, mouseX, mouseY) / sqrt(2); // Calculate side length based on diagonal
    float angle = atan2(mouseY - startY, mouseX - startX); // Angle of diagonal
    float halfDiag = dist(startX, startY, mouseX, mouseY) / 2; // Half the length of the diagonal
    // Calculate midpoint of the diagonal
    float midX = (startX + mouseX) / 2;
    float midY = (startY + mouseY) / 2;
    // Calculate offset for corners based on angle
    float offsetX = cos(angle + HALF_PI) * halfDiag;
    float offsetY = sin(angle + HALF_PI) * halfDiag;
    // Draw square using corners
    noFill();
    stroke(255);
    beginShape();
    vertex(midX + offsetX, midY + offsetY);
    vertex(midX - offsetX, midY - offsetY);
    vertex(startX, startY);
    vertex(mouseX, mouseY);
    endShape(CLOSE);
  }
  
  //shouldn't really modify this printout code unless there is a really good reason to
  if (userDone)
  {
    text("User completed " + trialCount + " trials", width/2, inchToPix(.4f));
    text("User had " + errorCount + " error(s)", width/2, inchToPix(.4f)*2);
    text("User took " + (finishTime-startTime)/1000f/trialCount + " sec per destination", width/2, inchToPix(.4f)*3);
    text("User took " + ((finishTime-startTime)/1000f/trialCount+(errorCount*errorPenalty)) + " sec per destination inc. penalty", width/2, inchToPix(.4f)*4);
    return;
  }

  //===========DRAW DESTINATION SQUARES=================
  for (int i=trialIndex; i<trialCount; i++) // reduces over time
  {
    pushMatrix();
    Destination d = destinations.get(i); //get destination trial
    translate(d.x, d.y); //center the drawing coordinates to the center of the destination trial
    rotate(radians(d.rotation)); //rotate around the origin of the destination trial
    noFill();
    strokeWeight(3f);
    if (trialIndex==i)
      stroke(255, 0, 0, 192); //set color to semi translucent
    else
      stroke(128, 128, 128, 128); //set color to semi translucent
    rect(0, 0, d.z, d.z);
    popMatrix();
  }

  //===========DRAW LOGO SQUARE=================
  pushMatrix();
  translate(logoX, logoY); //translate draw center to the center oft he logo square
  rotate(radians(logoRotation)); //rotate using the logo square as the origin
  noStroke();
  fill(60, 60, 192, 192);
  rect(0, 0, logoZ, logoZ);
  popMatrix();

  //===========DRAW EXAMPLE CONTROLS=================
  fill(255);
  text("Trial " + (trialIndex+1) + " of " +trialCount, width/2, inchToPix(.8f));
}

void mousePressed()
{
  if (startTime == 0) //start time on the instant of the first user click
  {
    startTime = millis();
    println("time started!");
  }
  
   if (!isDrawing) {
    startX = mouseX;
    startY = mouseY;
    isDrawing = true;
  } else {
    // On second click, finalize the square and check for validity
    isDrawing = false;
    finalizeSquareAndCheck(startX, startY, mouseX, mouseY);
  }
  
}

//probably shouldn't modify this, but email me if you want to for some good reason.
public boolean checkForSuccess()
{
  Destination d = destinations.get(trialIndex);  
  boolean closeDist = dist(d.x, d.y, logoX, logoY)<inchToPix(.05f); //has to be within +-0.05"
  boolean closeRotation = calculateDifferenceBetweenAngles(d.rotation, logoRotation)<=5;
  boolean closeZ = abs(d.z - logoZ)<inchToPix(.1f); //has to be within +-0.1"  

  println("Close Enough Distance: " + closeDist + " (logo X/Y = " + d.x + "/" + d.y + ", destination X/Y = " + logoX + "/" + logoY +")");
  println("Close Enough Rotation: " + closeRotation + " (rot dist="+calculateDifferenceBetweenAngles(d.rotation, logoRotation)+")");
  println("Close Enough Z: " +  closeZ + " (logo Z = " + d.z + ", destination Z = " + logoZ +")");
  println("Close enough all: " + (closeDist && closeRotation && closeZ));

  return closeDist && closeRotation && closeZ;
}

//utility function I include to calc diference between two angles
double calculateDifferenceBetweenAngles(float a1, float a2)
{
  double diff=abs(a1-a2);
  diff%=90;
  if (diff>45)
    return 90-diff;
  else
    return diff;
}

//utility function to convert inches into pixels based on screen PPI
float inchToPix(float inch)
{
  return inch*screenPPI;
}

void finalizeSquareAndCheck(float x1, float y1, float x2, float y2) {
  // Calculate the center of the drawn square
  float centerX = (x1 + x2) / 2;
  float centerY = (y1 + y2) / 2;
  
  // Calculate the size of the drawn square (using the length of the diagonal)
  float diagonalLength = dist(x1, y1, x2, y2);
  float squareSize = diagonalLength / sqrt(2); // Side length of the square

  // Retrieve the current target square for comparison
  Destination target = destinations.get(trialIndex);

  // Check if the drawn square's center is close to the target center
  // and if the sizes are similar within a tolerance
  float centerDistance = dist(centerX, centerY, target.x, target.y);
  boolean isCenterClose = centerDistance < inchToPix(0.1); // Example tolerance for center proximity
  
  // Tolerance for size comparison, e.g., within 10% of the target size
  boolean isSizeClose = abs(squareSize - target.z) < target.z * 0.1;

  if (isCenterClose && isSizeClose) {
    // If both conditions are met, consider it a success
    println("Square correctly drawn");
    trialIndex++; // Move to the next target
    if (trialIndex >= trialCount) {
      userDone = true; // Mark as done if this was the last target
      finishTime = millis(); // Record the finish time
    }
    fill(0, 255, 0);
    text("Success!", width/2, height - 20);
    successSound.rewind();
    successSound.play();
  } else {
    // If the square doesn't match the target criteria, increment the error count
    errorCount++;
    println("Square incorrectly drawn");
    trialIndex++;
     // Display failure message
    fill(255, 0, 0);
    text("Not successful. Try again.", width/2, height - 20);
    errorSound.rewind();
    errorSound.play();
  }
  

  // Reset variables for drawing the next square
  isDrawing = false;
}
