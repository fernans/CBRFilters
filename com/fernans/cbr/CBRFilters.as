package com.fernans.cbr {
	
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.media.Video;
	import flash.media.Camera;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import flash.text.TextField;
	import flash.sensors.Accelerometer;
	import flash.events.AccelerometerEvent;
	import flash.sensors.Geolocation;
	import flash.events.GeolocationEvent;
	import flash.display.DisplayObject;
	
	public class CBRFilters extends MovieClip {
				
		public static const MODE_NONE:Number=0;	// no image (black)
		public static const MODE_VIDEO:Number=1;	// direct image (no filter)
		public static const MODE_BASIC:Number=2;	// basic filter (just channel composite)
		public static const MODE_FULL:Number=3;	// full filter (lookup table)
		private var currentMode:Number=MODE_NONE;
		
		public static const FILTER_NONE:Number=0;
		public static const FILTER_XRAY:Number=1;
		public static const FILTER_UV:Number=2;
		public static const FILTER_INFRARED:Number=3;
		public static const FILTER_CBR:Number=4;
		private var currentFilter:Number=FILTER_NONE;
		
		public static const CBRMODE_NIGHT:Boolean=false;
		public static const CBRMODE_DAY:Boolean=true;
		private var modeDay:Boolean=CBRMODE_DAY;
		private var umbral:Number=128;
		private var margin:Number=24; // 20%;
		
		// events
		public const UMBRAL_CHANGE:String="UMBRAL_CHANGE";
		
		private var filterValues:Array;
		private var lookupTables:Array;
				
		private var cam:Camera;				// capture device (camera)
		private var video:Video;			// video image (frames)
		private var bmd:BitmapData;			// processing bitmap data (pixels)
		private var output:Bitmap;			// visible image (bitmap)
		private var filter:ColorMatrixFilter;	// filter object to apply
		private var a:Vector.<uint>;		// Alpha lookup table
		private var r:Vector.<uint>;		// Red lookup table
		private var g:Vector.<uint>;		// Green lookup table
		private var b:Vector.<uint>;		// Blue lookup table
		private var cbr:CBR_graphic=new CBR_graphic();		// cbr backgound
		private var background:Sprite;
				
		private var fpsTimer:Timer;
		private var fpsCount:Number=0;
		private var fpsLast:Number=0;
		private var text_fps:TextField=null;
		
		private var _camW:Number=320;
		private var _camH:Number=240;
		private var _camFps:Number=30;
		private var _camId:Number=0;
		
		public var debugMode:Boolean=true;
		
		private var accl:Accelerometer=null;
		private var geom:Geolocation=null;
		private var heading:Number=0;
		private var cbrSize:Number=0;
		
		public var offsetX:Number=0;
		public var offsetY:Number=0;
		public var offsetZ:Number=90;
		public var offsetH:Number=-90;
		
		public var smoothH:Number=0.5;
		public var smoothAlt:Number=0.5;
		public var smoothAng:Number=0.5;
		
		public var snapH:Number=10;
		public var snapAlt:Number=10;
		public var snapAng:Number=10;
		
		private var lastHeading:Number=NaN;
		private var lastAngle:Number=NaN;
		private var lastAlt:Number=NaN;
		
		/////////////////////////////////////////////////////////////////////////////////////
		
		public function CBRFilters(camWidth:Number=320, camHeight:Number=240, camFps:Number=30, camId:Number=0) {
			ftrace("constructor");

			background=new Sprite();
			background.graphics.clear();
			background.graphics.beginFill(0);
			background.graphics.drawRect(0,0,camWidth-1,camHeight-1);
			background.graphics.endFill();
			addChild(background);
			
			this.setCamera(camWidth,camHeight,camFps,camId);
			
			createFilterValues();
			createLookupTables();
			
			addChild(cbr);
			cbr.visible=false;
			cbr.mask=background;
			cbr.scaleX=cbr.scaleY=5;
			cbrSize=cbr.width;
			
			
			if (Accelerometer.isSupported) {
				accl=new Accelerometer();
				accl.setRequestedUpdateInterval(40); // 
				accl.addEventListener(AccelerometerEvent.UPDATE, acclUpdate);
			}
			if (Geolocation.isSupported){	
				geom=new Geolocation();
				geom.setRequestedUpdateInterval(40);
				geom.addEventListener(GeolocationEvent.UPDATE, onGeoUpdate);
			}
			
			addEventListener(MouseEvent.CLICK, onClick);
			ftrace("---------------------");
		};
		
		private function ftrace(... m) {
			if (debugMode) trace("com.fernans.cbr.CBRFilters :: "+m);
		}
		
		/////////////////////////////////////////////////////////////////////////////////////
		
		private function _init() {
			if (cam!=null || video!=null || bmd!=null || output!=null) return;
			
			ftrace("connecting to camera...");
			
			cam=Camera.getCamera(_camId.toString());
			if (cam==null) {
				ftrace("Cannot connect to camera Id: "+_camId);
				return;
			}
			cam.setMode(_camW,_camH,_camFps);
			ftrace("got camera mode: "+cam.width,"x"+cam.height+"@"+cam.fps);
			video=new Video(cam.width, cam.height);
			video.attachCamera(cam);
			
			bmd=new BitmapData(cam.width,cam.height,true,0);
			output=new Bitmap(bmd,"auto",true);
			this.addChild(output);
			
			// fps detector
			fpsTimer=new Timer(1000);
			fpsCount=0;
			fpsLast=Number.NaN;
			fpsTimer.addEventListener(TimerEvent.TIMER, countFps);
			
			cam.addEventListener(Event.VIDEO_FRAME, processVideo);
		}
		
		private function _stop() {
			if (cam==null || video==null || bmd==null || output==null) return;
			
			ftrace("disconnecting camera...");
			
			if (fpsTimer!=null)	{
				fpsTimer.stop();
				fpsTimer.removeEventListener(TimerEvent.TIMER, countFps);
				fpsTimer=null;
			}
			
			currentMode=MODE_NONE;
			cam.removeEventListener(Event.VIDEO_FRAME, processVideo);
			removeChild(output);
			output=null;
			bmd.dispose();
			bmd=null;
			video.attachCamera(null);
			video=null;
			cam=null;
		}
		
		private function setCamera(camWidth:Number=320, camHeight:Number=240, camFps:Number=30, camId:Number=0) {
			var lastMode:Number=this.currentMode;
			this._stop();
			
			background.graphics.clear();
			background.graphics.beginFill(0);
			background.graphics.drawRect(0,0,camWidth-1,camHeight-1);
			background.graphics.endFill();
			
			_camW=camWidth;
			_camH=camHeight;
			_camFps=camFps;
			_camId=camId;
			
			// auto-restart camera on last mode
			if (lastMode!=MODE_NONE) {
				currentMode=lastMode;
				setFilter(currentFilter);
				_init();
			}
		}
		///////////////////////////////////////////////////////////////////////////////////////
		public function selectCamera(camId:Number, camWidth:Number=NaN, camHeight:Number=NaN, camFps:Number=NaN) {
			if (!isNaN(camId)) {
				if (isNaN(camWidth)) camWidth=_camW;
				if (isNaN(camHeight)) camHeight=_camH;
				if (isNaN(camFps)) camFps=_camFps;
				
				setCamera(camWidth,camHeight,camFps,camId);
			}
		}
		
		public function setCBRImage(d:DisplayObject=null) {
			if (d==null) return;
			cbr.removeChildren(); // all
			cbr.addChild(d);
			d.x=-d.width*0.5;
			d.y=-d.height*0.5;
			cbr.scaleX=cbr.scaleY=1;
			cbrSize=cbr.width;
		}
		
		public function setCBRScale(scale:Number) {
			cbr.scaleX=cbr.scaleY=scale;
			cbrSize=cbr.width;
		}
		public function getCBRScale():Number {
			return cbr.scaleX;
		}

		private function acclUpdate(e:AccelerometerEvent=null) {
			if (accl.muted) return;
			
			// read accl values
			var aX:Number = e.accelerationX;
			var aY:Number = e.accelerationY;	
			var aZ:Number = e.accelerationZ;
			// constraint into -1..0..1
			if (aX < -1) aX = -1;
			if (aX > 1) aX = 1;
			if (aY < -1) aY = -1;
			if (aY > 1) aY = 1;
			if (aZ < -1) aZ = -1;
			if (aZ > 1) aZ = 1;
			
			// vector length
			var mag:Number = Math.sqrt(aX*aX+aY*aY+aZ*aZ);
			// angle respect Y
			var angleX:Number = (90-Math.round((180/Math.PI)*Math.acos(aX/mag)) )+offsetX; // 0=vertical, -90=landscape right, 90=landscape left
			var angleY:Number = (90-Math.round((180/Math.PI)*Math.acos(aY/mag)) )+offsetY; // when +: angleX=angleX,   when -: angleX=180-angleX (if angleX>180, angleX=360-angleX)
			var angleZ:Number = (90-Math.round((180/Math.PI)*Math.acos(aZ/mag)) )+offsetZ; // 0=ceil, 90=horizon
			//trace(aX,aY,aZ);
			//trace(angleX,angleY,angleZ);
			//trace(heading);
			//trace("---");
			
			// final Values
			var finalHeading:Number=heading;
			var finalAltitude:Number=angleZ;
			var finalAngle:Number=angleX;
			
			// angle corrections (by horizontal)
			if (angleY<0) {
				finalAngle=180-finalAngle;
			}
			// heading correction (by horizontal)
			finalHeading-=angleX;
			// angle corrections (by upside-down)
			//if (angleY<0) {
				//finalHeading+=180; // look to oposite direction
				//finalAngle+=180; // view upside-down
			//}
			// angle correction (by heading) (orient graphic)
			finalAngle-=finalHeading;
			
			// keep on -180..0..180
			//if (finalAngle>180) finalAngle=finalAngle-360;
			
			// trace
			//trace("heading: "+finalHeading);
			//trace("    alt: "+finalAltitude);
			//trace("  angle: "+finalAngle);
			//trace("=========");
			
			// final Values in Radians
			var finalAngleR:Number=(finalAngle)*Math.PI/180;
			var finalHeadingR:Number=(finalHeading+offsetH)*Math.PI/180;
			
			// smooth
			if (isNaN(lastAngle)) lastAngle=finalAngleR;
			if (isNaN(lastAlt)) lastAlt=finalAltitude;
			if (isNaN(lastHeading)) lastHeading=finalHeadingR;
			
			// snap (keeps on last value if too low variation)
			if (Math.abs(finalAngleR-lastAngle)<(this.snapAng*Math.PI/180)) finalAngleR=lastAngle;
			if (Math.abs(finalAltitude-lastAlt)<this.snapAlt) finalAltitude=lastAlt;
			if (Math.abs(finalHeadingR-lastHeading)<(this.snapH*Math.PI/180)) finalHeadingR=lastHeading;
			
			
			// keep near steps (> half loop - in radians)
			if (Math.abs(lastHeading-finalHeadingR)>Math.PI) lastHeading-=(2*Math.PI);
			if (Math.abs(lastAngle-finalAngleR)>Math.PI) lastAngle-=(2*Math.PI);
			// smooth 0 = direct, 1=fixed
			finalAngleR=((1-smoothAng)*finalAngleR)+(smoothAng*lastAngle);
			finalAltitude=((1-smoothAlt)*finalAltitude)+(smoothAlt*lastAlt);
			finalHeadingR=((1-smoothH)*finalHeadingR)+(smoothH*lastHeading);
			
			// store for next smooth step
			lastAngle=finalAngleR;
			lastAlt=finalAltitude;
			lastHeading=finalHeadingR;
			
			
			// move & rotate cbr map
			finalAngleR-=this.rotation*Math.PI/180;	// visible-object rotation counter-effect
			var posx:Number=(Math.cos(finalHeadingR)*finalAltitude)*(cbrSize/360);
			var posy:Number=(Math.sin(finalHeadingR)*finalAltitude)*(cbrSize/360);
			cbr.x=(Math.cos(finalAngleR)*posx)-(Math.sin(finalAngleR)*posy);
			cbr.y=(Math.sin(finalAngleR)*posx)+(Math.cos(finalAngleR)*posy);
			cbr.rotation=finalAngleR*180/Math.PI;
			
			// center map on screen
			cbr.x+=(this._camW*0.5);
			cbr.y+=(this._camH*0.5);
			
		}
		
		private function onGeoUpdate(e:GeolocationEvent=null) {
			heading=-e.heading;
		}
		
		/////////////////////////////////////////////////////////////////////////////////////
		public function setCBRmode(mode:Boolean=CBRMODE_DAY) {
			ftrace("set CBR mode day "+mode);
			modeDay=mode;
			if (currentMode==FILTER_CBR) setFilter(currentFilter); // update cbr day-night mode
		}
		
		public function setCBRlevel(level:Number=128) {
			if (level<0) level=0;
			if (level>255) level=255;
			umbral=level;
			setFilter(currentFilter);
		}
		public function getCBRlevel():Number {
			return umbral;
		}
		
		public function setCBRmargin(level:Number=12) {
			if (level<0) level=0;
			if (level>255) level=255;
			margin=level;
			setFilter(currentFilter);
		}
		public function getCBRmargin():Number {
			return margin;
		}
		
		public function setMode(mode:Number=MODE_NONE) {
			ftrace("set mode "+mode);
			switch(mode) {
				case MODE_NONE:
					currentMode=MODE_NONE;
					_stop();
				break;
				case MODE_VIDEO:
					currentMode=MODE_VIDEO;
					setFilter(currentFilter);
					_init();
				break;
				case MODE_BASIC:
					currentMode=MODE_BASIC;
					setFilter(currentFilter);
					_init();
				break;
				case MODE_FULL:
					currentMode=MODE_FULL;
					setFilter(currentFilter);
					_init();
				break;
				default:
					// ignore... no mode change
				break;
			}
			ftrace("---------------------");
		}
				
		public function setFilter(filter:Number=FILTER_NONE) {
			ftrace("setFilter : "+filter);
			currentFilter=filter;
			cbr.visible=false; // ocultar fondo cbr
			var filterMatrix:Array=new Array();		// values to construct a filter
			if (currentFilter==FILTER_CBR) {
				cbr.visible=true; // mostrar fondo cbr
				// contruir lookat table para modo FULL
				// construir filtro CBR, desde level+-margin
				a=lookupTables[currentFilter][3] as Vector.<uint>;
				var cbrTable:Array=[new Point(0,255), // 0=opaco
									new Point(umbral-margin,255),  		// umbral-margin    = opaco
									new Point(umbral-(margin*0.5),0),   // umbral-50%margin = transp
									new Point(umbral,0),    			// umbral           = transp
									new Point(umbral+(margin*0.5),0),	// umbral+50%margin = transp
									new Point(umbral+margin,255),			// umbral+maring    = opaco
									new Point(255,255)]; // blanco=opaco
				a=updateTable(cbrTable); // create lookat table
				lookupTables[currentFilter][3]=a; // store new lookat table
				ftrace("umbral: "+umbral+"     margin="+margin);
				
				// mantener dia/noche si modo BASIC
				// construir filtro CBR, segun dia o noche
				if (modeDay) {
					// filter Day
					filterMatrix = new Array();
					filterMatrix = filterMatrix.concat([1, 0, 0, 0, 0]); // red
					filterMatrix = filterMatrix.concat([0, 1, 0, 0, 0]); // green
					filterMatrix = filterMatrix.concat([0, 0, 1, 0, 0]); // blue
					filterMatrix = filterMatrix.concat([-1, -1, -1, 0, umbral*3]); // alpha (765...0) claros=transp	
					this.filter = new ColorMatrixFilter(filterMatrix);
				} else {
					// filter Night
					filterMatrix = new Array();
					filterMatrix = filterMatrix.concat([1, 0, 0, 0, 0]); // red
					filterMatrix = filterMatrix.concat([0, 1, 0, 0, 0]); // green
					filterMatrix = filterMatrix.concat([0, 0, 1, 0, 0]); // blue
					filterMatrix = filterMatrix.concat([1, 1, 1, 0, -umbral*3]); // alpha (0...765) oscuros=transp
					this.filter = new ColorMatrixFilter(filterMatrix);
				}				
			} else if (currentFilter<filterValues.length) {
				// construir filtro, segun currentFilter
				filterMatrix = filterMatrix.concat(filterValues[currentFilter][0]); // red
				filterMatrix = filterMatrix.concat(filterValues[currentFilter][1]); // green
				filterMatrix = filterMatrix.concat(filterValues[currentFilter][2]); // blue
				filterMatrix = filterMatrix.concat(filterValues[currentFilter][3]); // alpha
				this.filter = new ColorMatrixFilter(filterMatrix);
				ftrace("---------------------");
			}
			
			if (currentFilter<lookupTables.length) {
				// cargar lookup table, segun currentFilter
				r=lookupTables[currentFilter][0] as Vector.<uint>;
				g=lookupTables[currentFilter][1] as Vector.<uint>;
				b=lookupTables[currentFilter][2] as Vector.<uint>;
				a=lookupTables[currentFilter][3] as Vector.<uint>;
				//ftrace("---------------------");
				//ftrace(r);
				//ftrace(g);
				//ftrace(b);
				//ftrace(a);
			}
		}
		
		public var or:Bitmap=null;
		public function onClick(e:MouseEvent=null) {
			if (currentFilter==FILTER_CBR && e!=null) {
				//trace("click on: "+e.localX+", "+e.localY);
				// work on original bitmap (pre-processed)
				var temp:BitmapData=new BitmapData(video.width,video.height,false,0);
				temp.draw(video);
				var colorRef:uint=temp.getPixel(e.currentTarget.mouseX, e.currentTarget.mouseY);//(e.localX,e.localY);
				//colorRef=0xFF0000;
				var refr:int=(colorRef>>16)&0xFF;
				var refg:int=(colorRef>>8)&0xFF;
				var refb:int=(colorRef>>0)&0xFF;
				var refa:int=Math.floor((refr+refg+refb)/3);
				//trace("r:"+refr+" g:"+refg+" b:"+refb+" = umbral:"+refa);
				
				/*
				if (modeDay) {
					// subir un 33%
					//refa=255-((255-refa)*0.66);
					refa=refa*0.66+86.7;
				} else {
					// bajar un 33%
					refa=refa*0.66;
				}
				//*/
				
				umbral=refa;
				setFilter(this.currentFilter);
				// lanzar evento
				this.dispatchEvent(new Event(this.UMBRAL_CHANGE));
			}
		}
		
		/////////////////////////////////////////////////////////////////////////////////////
		
		private function processVideo(e:Event=null) {
			if (currentMode>=MODE_VIDEO)
				bmd.draw(video);	// copy video input
			
			if (currentMode==MODE_BASIC)
				applyBasicFilter(); // aplicar filtro basico
				 
			if (currentMode==MODE_FULL) {
				if (currentFilter!=FILTER_CBR) applyBasicFilter(); // pre aplicar filtro basico
				applyFullFilter(); // aplicar filtro por lookuptable
			}
				
			if (fpsTimer.running) fpsCount++;
		}
		
		//////////////////////////////////////////////////////////////////////////////////////
		
		public function setFps(active:Boolean=true) {
			ftrace("setFPS: "+active);
			if (active) {
				fpsCount=0;
				fpsLast=0;
				fpsTimer.reset();
				fpsTimer.start();
				text_fps=new TextField();
				text_fps.text="---";
				addChild(text_fps);
			} else {
				fpsTimer.stop();
				fpsCount=0;
				fpsLast=Number.NaN;
				if (text_fps!=null) {
					ftrace(text_fps);
					removeChild(text_fps);
				}
				text_fps=null;
			}
		}
		
		private function countFps(e:Event=null) {
			fpsLast=fpsCount;
			text_fps.text=fpsLast.toString();
			fpsCount=0;
		}
		
		public function getFps():Number {
			return fpsLast;
		}
		
		
		//////////////////////////////////////////////////////////////////////////////////////
		
		private function applyBasicFilter() {
			bmd.applyFilter(bmd,bmd.rect,new Point(),filter);
		}
		
		// defined outside to keep memory inter-frames
		private var p:Vector.<uint>;	// bitmap as uint vector
		private var plen:uint;			// length of vector
		private var pval:uint; 			// input value (compossed ARGB)
		private var ir:uint, ig:uint, ib:uint, ia:uint; // input values (descompossed)
		private var oval:uint;			 // output value (compossed ARGB)
		
		private function applyFullFilter() {
			p=bmd.getVector(bmd.rect);
			plen=p.length;

			for (var i:uint=0;i<plen;i++) {
				pval=p[i];
				ia=(pval>>24)&0xFF; // shift Argb
				ir=(pval>>16)&0xFF; // shift aRgb
				ig=(pval>>8)&0xFF; // shift arGb
				ib=(pval)&0xFF; // noshift nedded argB

				ia=a[Math.floor((ir+ig+ib)/3)]; // lookup table replacement A (basado en nivel de luz)
				ir=r[ir]; // lookup table replacement R
				ig=g[ig]; // lookup table replacement G
				ib=b[ib]; // lookup table replacement B

				oval=(ia<<24)+(ir<<16)+(ig<<8)+(ib); // output compossed
				p[i]=oval; // store final value
			}
			bmd.setVector(bmd.rect,p);
		}
		
		
		///////////////////////////////////////////////////////////////////////////////////////
		
		private function createFilterValues() {
			filterValues=new Array();
			var temp:Array;
			// filter 0=NONE
			temp=new Array();
			temp.push(selectFx(1)); // red
			temp.push(selectFx(2)); // green
			temp.push(selectFx(3)); // blue
			temp.push(fA); // alpha
			filterValues.push(temp);
			// filter 1=XRAY
			temp=new Array();
			temp.push(selectFx(-1)); // red
			temp.push(selectFx(-1)); // green
			temp.push(selectFx(-4)); // blue
			temp.push(fA); // alpha
			filterValues.push(temp);
			// filter 2=UV
			temp=new Array();
			temp.push(selectFx(1)); // red
			temp.push(selectFx(4)); // green
			temp.push(selectFx(1)); // blue
			temp.push(fA); // alpha
			filterValues.push(temp);
			// filter 3=INFRARED
			temp=new Array();
			temp.push(selectFx(5)); // red
			temp.push(selectFx(1)); // green
			temp.push(selectFx(4)); // blue
			temp.push([0, 0, 0, 1, 0]); // alpha
			filterValues.push(temp);
			
			// filter 4=CBR (alpha level)
			temp=new Array();
			temp.push([1,0,0,0,0]); // R
			temp.push([0,1,0,0,0]); // G
			temp.push([0,0,1,0,0]); // B
			temp.push([0.33,0.33,0.33,0,0]); // A
			filterValues.push(temp);
		}
		
		private var f0:Array=[0,0,0,0,0];
		private var fR:Array=[1,0,0,0,0];
		private var fG:Array=[0,1,0,0,0];
		private var fB:Array=[0,0,1,0,0];
		private var fL:Array=[0.33,0.33,0.33,0,0];
		private var fSR:Array=[2, -1, -1, 0, 0]; //(probar tambien con [ 4,-4, 0] // [4, 0,-4])
		private var fSG:Array=[-4, 4,  0, 0, 0]; // probar tambien con [-1, 2,-1] // [0, 4,-4]
		private var fSB:Array=[-4, 0,  4, 0, 0]; // probar tambien con [-1,-1, 2] // [0,-4, 4]
		private var fiR:Array=[-1,0,0,0,255];
		private var fiG:Array=[0,-1,0,0,255];
		private var fiB:Array=[0,0,-1,0,255];
		private var fiL:Array=[-0.33,-0.33,-0.33,0,255];
		private var fiSR:Array=[-2, +1, +1, 0, 255]; //(probar tambien con [-4,+4, 0] // [-4, 0,+4])
		private var fiSG:Array=[+4, -4,  0, 0, 255]; // probar tambien con [+1,-2,+1] // [ 0,-4,+4]
		private var fiSB:Array=[+4,  0, -4, 0, 255]; // probar tambien con [+1,+1,-2] // [ 0,+4,-4]
		private var fA:Array=[0,0,0,1,0]; // alfa constante
		
		private function selectFx(num:Number):Array {
			//if (num<0) num=7-num;
			switch(num) {
				case 0:
					return f0;
				case 1:
					return fR;
				case 2:
					return fG;
				case 3:
					return fB;
				case 4:
					return fL;
				case 5:
					return fSR;
				case 6:
					return fSG;
				case 7:
					return fSB;
				case -1:
					return fiR;
				case -2:
					return fiG;
				case -3:
					return fiB;
				case -4:
					return fiL;
				case -5:
					return fiSR;
				case -6:
					return fiSG;
				case -7:
					return fiSB;
				default:
					return [0,0,0,0,0];
			}
		}
		
		///////////////////////////////////////////////////////////////////////////////////////
		private function createLookupTables() {
			lookupTables=new Array();
			var tempTable:Array;
			var linearTable:Array=[new Point(0,0),new Point(42,42),new Point(85,85),new Point(127,127),new Point(170,170),new Point(212,212),new Point(255,255)];
			var constantUpTable:Array=[new Point(0,255),new Point(42,255),new Point(85,255),new Point(127,255),new Point(170,255),new Point(212,255),new Point(255,255)];

			// filter 0=NONE
			tempTable=new Array;
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable(constantUpTable));
			lookupTables.push(tempTable);
			
			// filter 1=XRAY
			tempTable=new Array;
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable([new Point(0,0),new Point(53,28),new Point(90,66),new Point(128,136),new Point(160,188),new Point(196,231),new Point(255,255)]));
			tempTable.push(updateTable(constantUpTable));
			lookupTables.push(tempTable);
			
			// filter 2=UV
			tempTable=new Array;
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable([new Point(0,0),new Point(52,12),new Point(97,32),new Point(147,80),new Point(194,138),new Point(228,204),new Point(255,255)]));
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable(constantUpTable));
			lookupTables.push(tempTable);
			
			// filter 3=INFRARED
			tempTable=new Array;
			tempTable.push(updateTable([new Point(0,0),new Point(20,66),new Point(74,166),new Point(117,229),new Point(176,247),new Point(221,255),new Point(255,255)]));
			tempTable.push(updateTable([new Point(0,0),new Point(20,45),new Point(80,237),new Point(104,255),new Point(143,60),new Point(162,4),new Point(255,0)]));
			tempTable.push(updateTable([new Point(0,51),new Point(18,149),new Point(46,183),new Point(68,140),new Point(90,52),new Point(132,0),new Point(255,0)]));
			tempTable.push(updateTable(constantUpTable));
			lookupTables.push(tempTable);
			
			// filter 4=CBR
			tempTable=new Array;
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable(linearTable));
			tempTable.push(updateTable(constantUpTable));
			lookupTables.push(tempTable);
		}
		
		private const NUM_PUNTOS:Number=7;
		private function updateTable(p:Array=null):Vector.<uint> {
			var table:Vector.<uint>=new Vector.<uint>();
			for (var h:uint=0;h<256;h++) table.push(h); // lineal
			if (p!=null) { // non lineal
				for (var i:uint=0;i<(NUM_PUNTOS-1);i++) 
				{
					var pini:Point=p[i] as Point;
					var pfin:Point=p[i+1] as Point;
					var ystep:int=(pfin.y-pini.y)/(pfin.x-pini.x);
					var value:int=(pini.y);
					for (var j:uint=pini.x;j<pfin.x;j++) {
						table[j]=value;
						value+=ystep;
					}
				}
			}
			return table;
		}
		
		///////////////////////////////////////////////////////////////////////////////////////
		
	}
}