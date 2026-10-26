package  {
	
	import flash.display.MovieClip;
	import flash.events.Event;
	
	import com.fernans.cbr.CBRFilters;
	
	public class CBRFilters_Test extends MovieClip {
		
		private var cbr:CBRFilters;
		
		public function CBRFilters_Test() {
			// constructor code
			addEventListener(Event.ADDED_TO_STAGE,init);
		}
		
		public function init(e:Event=null) {
			removeEventListener(Event.ADDED_TO_STAGE, init);
			trace("init");
			
			cbr=new CBRFilters();
			cbr.rotation=90;
			trace(cbr.height);
			cbr.x=(240+400)/2;
			cbr.y=(550-320)/2;
			addChild(cbr);
			
			cbr.setMode(CBRFilters.MODE_FULL);
			
			cbr.setFilter(CBRFilters.FILTER_CBR);
			cbr.setCBRmode(CBRFilters.CBRMODE_DAY); // solo aplicable en MODE_BASIC
			cbr.setCBRlevel(128); // nivel de luz (aplicable tanto en MODE_BASIC DAY/NIGH, como en MODE_FULL)
			cbr.setCBRmargin(24);  // margen de admision alrededor de level (solo aplicable en MODE_FULL)
			
			cbr.setFps(false);
			
			cbr.setCBRImage(new TestImage());	// sustituye la imagen CBR (4k) incluida "de serie"
			cbr.setCBRScale(10);				// aplica escala a la imagen de cbr (sustituida o "de serie")
			
			cbr.selectCamera(0);
		}
	}
	
}
