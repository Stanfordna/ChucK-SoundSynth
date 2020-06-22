// A SinOsc with ADSR Envelope
private class EnvelopedSinOsc {
    false => static int sustainTone;                         
    SinOsc osc;
    0.0 => osc.gain; // easiest way to add muted overtones
    0.0 => osc.freq; // good default frequency
    ADSR e; // template from which to make new ADSR's for every call to play
    ( 0.05::second, 0.05::second, 0.4, 0.5::second ) => e.set;
    
    public SinOsc getOsc() { return osc; }
    
    // Copy constructor for ADSR
    public ADSR adsr(ADSR other) {
        ADSR env;
        ( a(), d(), s(), r() ) => env.set;
        return env;
    }
    
    public static void enable() { true => sustainTone; }
    public static void disable() { false => sustainTone; }
    public static int isEnabled() { return sustainTone; }
    
    public dur a() {
        return e.attackTime();
    }
    public dur a(dur a) {
        a => e.attackTime;
        return a;
    }
    
    public dur d() {
        return e.decayTime();
    }
    public dur d(dur d) {
        d => e.decayTime;
        return d;
    }
    
    public float s() {
        return e.sustainLevel();
    }
    public float s(float s) {
        s => e.sustainLevel;
        return s;
    }
    
    public dur r() {
        return e.releaseTime();
    }
    public dur r(dur r) {
        r => e.releaseTime;
        return r;
    }
    
    public void value(float v) { v => e.value; }
    
    public float gain(float g) { g => osc.gain; return g; }
    public float gain() { return osc.gain(); }
    
    public float freq(float f) { f => osc.freq; return f; }
    public float freq() { return osc.freq(); }
    
    public void connect(UGen ugen) { e => ugen;	}
	public void disconnect(UGen ugen) { e =< ugen; }
    
    public void play(dur sustainTime, SinOsc vibrato) {
        adsr(e) @=> ADSR env;
        vibrato => osc => env => dac;
        2 => osc.sync;
        env.keyOn();
        env.attackTime() => now;
        env.decayTime() => now;
        sustainTime => now;
        env.keyOff();
        env.releaseTime() => now;
        vibrato =< osc =< env =< dac;
        return;
    }
    
    public void playWhilePressed(SinOsc vibrato){
        adsr(e) @=> ADSR env;
        vibrato => osc => env => dac;
        2 => osc.sync;
        env.keyOn();
        env.attackTime() => now;
        env.decayTime() => now;
        while(sustainTone) {
            5::samp => now;
        }
        env.keyOff();
        env.releaseTime() => now;
        vibrato =< osc =< env =< dac;
        return;
    }
    
    // corresponds to line 318
    public void keyOn(SinOsc vibrato) {
        adsr(e) @=> e;
        vibrato => osc => e => dac;
        2 => osc.sync;
        e.keyOn();
        e.attackTime() => now;
        e.decayTime() => now;
        vibrato =< osc =< e =< dac;
        return;
    }
    
    public void sustain(SinOsc vibrato) {
        vibrato => osc => e => dac;
        2 => osc.sync;
        e.state() => int state;
        if ( state == 2 || state == 3  ) {
            500::samp => now;
        }
        vibrato =< osc =< e =< dac;
        return;
    }
    
    public void keyOff(SinOsc vibrato) {
        vibrato => osc => e => dac;
        2 => osc.sync;
        e.state() => int state;
        if ( state == 2 || state == 3 ) {
            e.keyOff();
            e.releaseTime() => now;
            0.5::second => now;
            vibrato =< osc =< e =< dac;
        }
        return;
    }
}

// dynamic array of dampened harmonics. osc[1] will always be fundamental,
// osc[2] will always be second harmonic, etc.  We will mute or not play
// certain overtones.
private class ComplexWaveOsc {
    EnvelopedSinOsc fundamental; // fundamental frequency of the wave
    440 => fundamental.freq;
    1 => fundamental.gain;
	EnvelopedSinOsc osc[2]; // vibrato + fundamental + overtones
    fundamental @=> osc[1]; // add fundamental to osc array
    osc[0].getOsc() @=> SinOsc vib;
    
    public SinOsc vibrato() { return vib; }
    
    public SinOsc vibrato(float v) {
        v => vib.freq;
        return vib;
    }
    
    public SinOsc vibrato(float v, float g) {
        g => vib.gain;
        v => vib.freq;
        return vib;
    }
    
	public float gain() { return osc[1].gain(); }
    
    // set gains of fundamental frequency 
    // and overtones while maintaining their rations
    public float gain(float g)
	{
        g / osc[1].gain() => float ratio;
		for ( 0 => int i; i < osc.cap(); i++ ) {
            (ratio * osc[i].gain()) => osc[i].gain;
        }
        return g;
	}
    
    // change gain of specific overtone.  First harmonic is index zero
    public float gain( float g, int harmonic )
	{
        0 => int i;
        if (harmonic < 0)
            return 0.0;
        else {
            // extend array of Dampened Oscillators if necessary to set the harmonic
            for (osc.cap() => i; i <= harmonic; 1 +=> i) {
                osc << new EnvelopedSinOsc; // add muted harmonic
                fundamental.freq() * (i) => osc[i].freq;
            }
        }
        g => osc[harmonic].gain;
        return g;
    }
    
    // return gain of specific overtone
    public float gain(int harmonic)
	{
        if ( harmonic < 0 || harmonic >= osc.cap() ) {
            return 0.0;
        }
        else {
            return osc[harmonic].gain();
        }
    }
    
    // get fundamental frequency
    public float freq() { 
        return fundamental.freq(); 
    }
    
    public float freq(int harmonic) { 
        if ( harmonic >= 0 && harmonic < osc.cap() ) {
            return osc[harmonic].freq(); 
        }
        return 0.0;
    }

    // set fundamental frequency and all overtones
	public float freq(float f) {
        // set fundamental to f and each overtone to its appropriate frequency
        // TODO: we may want to account for inharmonicity
        for ( 1 => int i; i < osc.cap(); i++ ) {
            f * i => osc[i].freq;
        }
        return f;
	}
    
    public float freq(float f, int harmonic) {
        0 => int i;
        if (harmonic < 0)
            return 0.0;
        else {
            // extend array of Dampened Oscillators if necessary to set the harmonic
            for (osc.cap() => i; i <= harmonic; 1 +=> i) {
                osc << new EnvelopedSinOsc; // add muted harmonic
                fundamental.freq() * (i) => osc[i].freq;
            }
        }
        f => osc[harmonic].freq;
        return f;
	}
    
    // attack getters and setters
    public dur a() {
        return fundamental.a();
    }
    public dur a(int harmonic) {
        if (harmonic < 0 || harmonic >= osc.cap()) {
            return 0::second;
        }
        return osc[harmonic].a();
    }
    public dur a(dur a) {
        a / osc[1].a() => float ratio;
		for ( 0 => int i; i < osc.cap(); i++ ) {
            (ratio * osc[i].a()) => osc[i].a;
        }
        return a;
    }
    public dur a(int harmonic, dur a) {
        if (harmonic < 0 || harmonic >= osc.cap()) {
            return 0::second;
        }
        a => osc[harmonic].a;
        return a;
    }
    
    // decay getters and setters
    public dur d() {
        return fundamental.d();;
    }
    public dur d(int harmonic) {
        if (harmonic < 0 || harmonic >= osc.cap()) {
            return 0::second;
        }
        return osc[harmonic].d();
    }
    public dur d(dur d) {
        d / osc[1].d() => float ratio;
		for ( 0 => int i; i < osc.cap(); i++ ) {
            (ratio * osc[i].d()) => osc[i].d;
        }
        return d;
    }
    public dur d(int harmonic, dur d) {
        if (harmonic < 0 || harmonic >= osc.cap()) {
            return 0::second;
        }
        d => osc[harmonic].d;
        return d;
    }
    
    // sustain getters and setters
    public float s() {
        return fundamental.s();
    }
    public float s(int harmonic) {
        if (harmonic < 0 || harmonic >= osc.cap()) {
            return 0.0;
        }
        return osc[harmonic].s();
    }
    public float s(float s) {
        s / osc[1].s() => float ratio;
		for ( 0 => int i; i < osc.cap(); i++ ) {
            (ratio * osc[i].s()) => osc[i].s;
        }
        return s;
    }
    public float s(int harmonic, float s) {
        if (harmonic < 0 || harmonic >= osc.cap()) {
            return 0.0;
        }
        s => osc[harmonic].s;        
        return s;
    }
    
    // release getters and setters
    public dur r() {
        return fundamental.r();
    }
    public dur r(int harmonic) {
        if (harmonic < 0 || harmonic >= osc.cap()) {
            return 0::second;
        }
        return osc[harmonic].r();
    }
    public dur r(dur r) {
        r / osc[1].r() => float ratio;
		for ( 0 => int i; i < osc.cap(); i++ ) {
            (ratio * osc[i].r()) => osc[i].r;
        }
        return r;
    }
    public dur r(int harmonic, dur r) {
        if (harmonic < 0 || harmonic >= osc.cap()) {
            return 0::second;
        }
        r => osc[harmonic].r;
        return r;
    }
    
    public dur totalDuration() {
        0::second => dur total;
        a() +=> total;
        d() +=> total;
        r() +=> total;
        return total;
    } 
    
    // bring sum of gains of harmonics to a reasonable level of .01
    // does not affect vibrato
    public void normalize()
    {
        0 => float totalGain;
        for ( 1 => int i; i < osc.cap(); i++ ) {
            osc[i].gain() +=> totalGain;
        }
        for ( 1 => int i; i < osc.cap(); i++ ) {
            osc[i].gain( osc[i].gain() / totalGain / 20 );
        }
    }
    
    public int cap() { return osc.cap(); }  
    
    // play all harmonics simultaneously
    public void play(dur sustainDuration) 
    {
        for ( 1 => int i; i < osc.cap(); 1 +=> i ) {
            spork ~ osc[i].play(sustainDuration, osc[0].getOsc());
        }
        totalDuration() + sustainDuration + 2::ms => now;
        return;
    }
    
    // changes static variable of EnvelopedOsc
    public void enableAll() {
        EnvelopedSinOsc.enable();
    }
    
    public void disableAll() {
        EnvelopedSinOsc.disable();
    }
    
    public void playUntilStopped() 
    {
        enableAll();
        for ( 1 => int i; i < osc.cap(); 1 +=> i ) {
            spork ~ osc[i].playWhilePressed(osc[0].getOsc());
        }
        a() => now;
        d() => now;
        while( EnvelopedSinOsc.isEnabled() ) {
            100::samp => now;
        }
        r() => now;
        return;
    }
}


// create a default ComplexSinOsc with frequency 440 Hz and Fundamental gain of 1
new ComplexWaveOsc @=> ComplexWaveOsc myOsc;

// ----------------------------------------------------
std.mtof(75.0) => myOsc.freq;
myOsc.gain(.3, 1); // fundamental frequency
myOsc.gain(.2, 2); // second harmonic, first overtone
myOsc.gain(.1, 3); // second overtone
myOsc.gain(.2, 4);
myOsc.gain(.01, 7);
myOsc.gain(.05, 8);
myOsc.gain(.025, 12); // skip a few overtones
myOsc.gain(.025, 15);
myOsc.gain(.0125, 18);
std.mtof(75.0) => myOsc.freq;

(6.0, 5.0) => myOsc.vibrato;
// ----------------------------------------------------

myOsc.normalize();
myOsc.gain() * 10 => myOsc.gain;

// play for2seconds
myOsc.play(1::second);
//std.mtof(75.0) => myOsc.freq;
//myOsc.play(2::second);
//std.mtof(60.0) => myOsc.freq;
//myOsc.play(2::second);
