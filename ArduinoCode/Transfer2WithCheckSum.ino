/*
Transfer.ino

this program creates a signal at the output port presented at the
left output. The input on the left is read and put on the serial port for processing
on the host computer.
*/

// setup codec parameters
// must be done before #includes
// see readme file in libraries folder for explanations
#define SAMPLE_RATE 2 // sets sample rate at 2kHz
#define ADCS 0 // use no ADCs ****
#define ADCHPD 1 // DC coupled

/*
- write a check sum so every 128 numbers, itll send a datalink escape then a 2,
  and then the check sum (the sum of all of it), instead of just sending 2 points.
- since dle and nl(newline) have special meaning, we encode them here as follows
*/

// include necessary libraries
#include <Wire.h>
#include <SPI.h>
#include <AudioCodec.h>

/** setup to get a word but send it out a byte at a time */
union CompoundWord { 
  uint16_t val;
  struct {
    uint8_t lsb;
    uint8_t msb;
  };
};

// create data variables for audio transfer
// even though there is no input needed, the codec requires stereo data
int left_in = 0; // in from codec (LINE_IN)
int right_in = 0;
int left_out = 0; // out to codec (HP_OUT)
int right_out = 0;
char dle = 16;  //create a variable for dle set to 16 so code is more readable
int count = 0;
int nl = 10;
CompoundWord checksum;
// create waveform lookup table
// PROGMEM stores the values in the program memory
// it is automatically included with AudioCodec.h
const int16_t waveform[] PROGMEM = {
  // this file is stored in AudioCodec.h and is a 1024 value
  //  lookup table of signed 16bit integers
  // you can replace it with your own waveform if you like
#include <bandlimited.inc>
};
unsigned int location; // lookup table value location


void setup() {
  // call this last if you are setting up other things
  AudioCodec_init(); // setup codec and microcontroller registers
  Serial.begin(115200); // initialize serial output port
}

void loop() {
  while (1); // reduces clock jitter
}  
/** sends a byte,  but if the byte that is being sent is a 10(), 
    then we should actually send a 16(dle) followed by a 1 */
void writeByte(char c)  
{
    while (!(SPSR & (1 << SPIF)))
      ;
    if (c == nl){
       Serial.write(dle);
       Serial.write(1);
    }
    else if (c == dle){    // to send a 16(dle), send a 16 followed a 16
       Serial.write(dle);
       Serial.write(dle); 
    }
    else{
       Serial.write(c); 
    }
}

// timer1 interrupt routine - all data processed here
ISR(TIMER1_COMPA_vect, ISR_NAKED) { // dont store any registers
  CompoundWord inWord;
  PORTB |= (1 << PORTB2); // toggle ss pina
  asm volatile ("out %0, %B1" : : "I" (_SFR_IO_ADDR(SPDR)), "r" (left_out) );
  PORTB &= ~(1 << PORTB2); // toggle ss pin
  while (!(SPSR & (1 << SPIF)));

  asm volatile ("out %0, %A1" : : "I" (_SFR_IO_ADDR(SPDR)), "r" (left_out) );
  asm volatile ("in r3, %0" : : "I" (_SFR_IO_ADDR(SPDR)) : "r3" );
  while (!(SPSR & (1 << SPIF))) { // wait for data transfer to complete
  }
  asm volatile ("out %0, %B1" : : "I" (_SFR_IO_ADDR(SPDR)), "r" (right_out) );
  asm volatile ("in r2, %0" : : "I" (_SFR_IO_ADDR(SPDR)) : "r2" );
  asm volatile ("movw %0, r2" : "=r" (inWord.val) : : "r2", "r3" );
  { // wait for data transfer to complete
    writeByte(inWord.lsb);
    writeByte(inWord.msb);
    while (!(SPSR & (1 << SPIF)))
      ;
    Serial.write(nl);
  }
  count++; // increment the count of how many numbers have been included in the checksum
  checksum.val += inWord.val;  // adds current word to the checksum
  if(count % 128 == 0) {   // every 128 numbers, write a checksum
  // indicate that we are sending a checksum by:
    Serial.write(dle);     // writing a dle
    Serial.write(2);       // and writing a 2
    // since the Arduino's serial port only sends a byte at a time, we will have to send each byte of the checksum separately 
    writeByte(checksum.lsb);   // Send the least significant byte
    writeByte(checksum.msb);    // Send the most significant byte
    Serial.write(nl); //writes a newline to delimit the checksum value from the continuing data
    //starts a new checksum by reseting the count and checksum values:
    count = 0; 
    checksum.val = 0;
  }
  // print the left channel to the serial port

  left_out = pgm_read_word_near(waveform + location); // get the next word from the waveform table

 
  location += 1;  // advance to the next location in the waveform table

  location &= 0x03ff; //loop at 1024

  reti(); // dont forget to return from the interrupt
}
