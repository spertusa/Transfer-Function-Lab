// Graphing sketch


// This program takes binary strings
// from the serial port at 115200 baud and graphs them. It expects values in the
// range -32000 and 32000, followed by a newline, or newline and carriage return

// Created 20 Apr 2005
// Updated 18 Jan 2008
// by Tom Igoe
// This example code is in the public domain9

import processing.serial.*;
import java.util.Arrays;

Serial myPort;        // The serial port
int xPos = 1;         // horizontal position of the graph
float oldNum = 0.;   // The old line position
float[] save=new float[1024];      // array to save output
PrintWriter outfile;  // output file
byte[] inByte = new byte[2];
int iter = 0;         // Counts input data sets of 1024 words

String outFileName = "Data";  //name of output text file
String outFileExt = ".txt";   //text file extension
int fileNumber = 0;           //output file number to add to name
Byte dle = 16;
short checksum = 0;
int checksumCount = 0;

void setup () {
  // set the window size:
  size(1023, 300);

  // List all the available serial ports
  // if using Processing 2.1 or later, use Serial.printArray()
  println(Serial.list());

  // I know that the first port in the serial list on my mac
  // is always my  Arduino, so I open Serial.list()[0].
  // Open whatever port is the one you're using.
  myPort = new Serial(this,"COM3", 115200);

  // don't generate a serialEvent() unless you get a newline character:
  myPort.bufferUntil('\n');

  // set inital background:
  background(0);
  outfile = createWriter(outFileName+str(fileNumber)+(outFileExt));
}

/** the draw function creates the pop up graph where the data is plotted*/
void draw () {
  // everything happens in the serialEvent()
}
int checkSumsSeen = 0;

/** decodeShort reads a 16-bit number from its input buffer, performing
  all necessary decoding of escapes, etc. and returns the number */
short decodeShort(byte[] buff) {
  byte[] inByte = new byte[2];
  int index = 0;
  for(int i = 0; i < 2; i++) {
    byte b = buff[index++];
    if(b == '\n') {
      throw new RuntimeException("Newlines must be escaped");   //If buffer receives new line, throw exception
    } else if(b == dle) {  //if the first byte is a dle it will check what the byte that follows it is
      b = buff[index++];
      if(b == dle)   //if the second byte is also a dle, then the program will interperet it as an actual dle in the code
  inByte[i] = dle;
      else if(b == 1)  //if the second byte is a one, the program will interperet it as a newline
  inByte[i] = '\n';  
      else
  throw new RuntimeException("Only DLE or newlines can be escaped");    
    } else { // Not a special character
      inByte[i] = b; 
    }
  }
  if(buff[index] != '\n')  //if buffer does not receive a newline after encoded bytes, throw an exception
    throw new RuntimeException("Missing newline delimiter");  
  return (short)((0xff&(short)(inByte[0])) + ((short)(inByte[1]) << 8));
}

/** This gets called to process the event every time there is a new line */
void serialEvent (Serial myPort) {
  try {
    byte[] buffer = myPort.readBytes();
    if(buffer[0] == dle && buffer[1] == 2) // This is a checksum
      processChecksum(decodeShort(Arrays.copyOfRange(buffer, 2, buffer.length))); //gives a copy of buffer without dle followed by a 2
    else
      processDataValue(decodeShort(buffer));  //processes data value
  } catch (RuntimeException e) {
    System.out.println(e.getMessage());
  }
}

/**this function processes the checksums*/
void processChecksum(short arduinoChecksum)
{
  checkSumsSeen++;
  if(checkSumsSeen < 4)
    return;
  if (arduinoChecksum != checksum)   //if the Arduino's cheksum and the Processing's checksum don't match, print them out as an error message but continue the program
    System.err.println("ProcessingChecksum: " + checksum + "   ArduinoChecksum: " + arduinoChecksum + "   checksumCount = " + checksumCount);
  checksum = 0;
  checksumCount = 0;
  return;
}

/**this function processes the data*/
void processDataValue(short dataValue) {
  checksum += dataValue;
  checksumCount++;   //add one to checkksum count each repitition
  float inNum = dataValue;
  float scaledValue = map(inNum, -32768, 32767, 0, height);  //scale value to fit on graph
  save[xPos]=inNum;

  // draw the line:
  stroke(127, 34, 255);
  line(xPos, oldNum, xPos, scaledValuez);
  oldNum=scaledValue;

  // if the number of points has reached the size of the plot
  if (xPos >= width) {
    // call up the write data thread
    if (iter > 4) {
      //skip the first 3 plots since they sometimes have funny data
      thread("writeData");
    }
    // increment the iteration
    iter ++;
    // set the x position back to the left edge of the plot
    xPos = 0;
    // clear the plot
    background(0);
  } else {
    // increment the horizontal position:
    xPos++;
  }

}

/** writes 1024 data values in ten different text files*/
void writeData() {
  if (fileNumber < 10 ) {
    for (int i=0; i < 1024; i=i+1) {
      outfile.println(save[i]);
    }
    outfile.close();
    if (fileNumber < 9 ) {
      String file = outFileName + fileNumber + outFileExt;  //building name of file being written
      outfile = createWriter(file);      //opening file
    }
    fileNumber ++;
  }
}

