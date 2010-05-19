
// Javascript object which draws structure in the browser using Jmol;
//
// StructureViewer.js
//
// $Id$

//------------------------------------------------------------------------------
//- OBJECT ---------------------------------------------------------------------
//------------------------------------------------------------------------------

// spoof a console, if necessary, so that we can run in IE (<8) without having
// to entirely disable debug messages
if ( ! window.console ) {
  window.console     = {};
  window.console.log = function() {};
}  

//------------------------------------------------------------------------------
//- class ----------------------------------------------------------------------
//------------------------------------------------------------------------------

var StructureViewer = Class.create({
  
  initialize: function( parent, accession, url, jmolUrl, options ){
    
    // ----------------------------------------
    // options should always contain the following parameters,
    // (1) seqType = Protein || DNA;
    // ----------------------------------------
    // Case Protein:
    // (2) mappingURl ( Protien to PDB mappings )
    // ----------------------------------------
    // Case DNA:
    // (2) mappingURL ( Protien to PDB mappings )
    // (3) transURL ( this is the das source which has the transformation of dna to uniprot mappings.
    // ----------------------------------------
    
    console.log( 'initialize: begins');
    
    // check for an existing DOM element;
    if( parent !== undefined ){
      this.setParent( parent );
    }else{
      this._throw( 'parent cannot be null' );
    }
    
    // check for accession;
    if( accession !== undefined ){
      this.setAccession( accession );  
    }else{
      this._throw( 'Accession cannot be null' );
    }
    
    // add the url
    if( /[\�\$\*\^]+/.test( jmolUrl ) ){
      this._throw( "Input URL contains invalid characters");
    }else{
      this._jmolUrl = jmolUrl;
    } 
    
     // add the jmol url
    if( /[\�\$\*\^]+/.test( url ) ){
      this._throw( "Input URL contains invalid characters");
    }else{
      this._url = url;
    }
    
//    this._options = {};
//    
//    // check the input options and store it in the object;
//    if( options.seqType !== undefined ){
//      
//      if( options.seqType === 'Protein' ){
//        
//        this._options.seqType    = options.seqType;
//        this._options.mappingUrl = ( options.mappingUrl !== undefined ) ? options.mappingUrl : null ;
//        
//        // now if the mappign url is null, then throw an exception;
//        if( this._options.mappingUrl === null ){
//          this._throw( 'mappingUrl has to be provided' );
//        }
//        
//      }else if( options.seqType === 'DNA' ){
//        
//        this._options.seqType    = options.seqType;
//        this._options.mappingUrl = ( options.mappingUrl !== undefined ) ? options.mappingUrl : null ;
//        this._options.transUrl   = ( options.transUrl !== undefined ) ? options.transUrl : null ;  
//        
//        // now if the mappign url is null, then throw an exception;
//        if( this._options.mappingUrl === null ){
//          this._throw( 'mappingUrl has to be provided' );
//        }
//        
//        // now if the mappign url is null, then throw an exception;
//        if( this._options.transUrl === null ){
//          this._throw( 'transUrl has to be provided' );
//        }
//        
//      } // end of else if DNA; 
//      
//    }else{
//      this._throw( 'seqType was not mentioned');
//    }
    
    // now make a request and fetch the strucutres which are similar to the uniprot sequences;
    this.fetchStructures();
    
  },  // end of initialize;
  
  //------------------------------------------------------------------------------
  //- Methods --------------------------------------------------------------------
  //------------------------------------------------------------------------------
  
  // method which fetches the structures which are similar to the accession;
  fetchStructures: function(){
    var that = this;
    
    // now create the query string and make a request;
    var queryString = this._url + '?acc=' + this._accession;
    console.log( 'fetchStructures: the queryString is |%s|',queryString );
    
    // now make the request using YAHOO get;
    var objTransaction = YAHOO.util.Get.script( queryString, {
      onSuccess: function( response ){
        
        // remove the script tag from beign added to the DOM,
        response.purge();
        
        if( typeof structure === 'string' ){
          console.log( '****the type of structure is '+ typeof structure +'|'+structure );  
          that._parent.update( structure );
          
          // now set the readystate to false;
          that.setReadyState( false );
          
        }else{
          
          that._parent.update( "Structures similar to <strong>"+that._accession+"</strong>" );
          
          // now add the response to another function;
          that.structureOptions( structure );
          
          // now set the readyState to true;
          that.setReadyState( true );  
        }
        
      } // end of onsuccess;
      
    } );  // end of objTransaction;
  },
  
  //----------------------------------------------------------------------------
  
  // method which retrieves the structures and parses it;
  structureOptions: function( structure ){
    
    var selectEl = new Element( 'select',{ 'id': 'pdb_id' } );
    
    // while walking down the strucutre array, build a new processed structures hash;
    var processedStructure = new Hash();
    
    // walk down the array to get the vales;
    $A( structure ).each( function( pdb ){
      console.log( 'the acc, start, end is |%s|%d|%d| ', pdb.acc, pdb.start, pdb.end );
      
      processedStructure.set( pdb.acc, pdb );
      // now create the option element and add as child of select;
      var optEl = new Element( 'option',{ 'value': pdb.acc } );
      optEl.update( pdb.acc );
      
      selectEl.appendChild( optEl );
        
    } );
    
    this._processedStructure = processedStructure;
    console.log('the processed Strucutre is '+ this._processedStructure.inspect() );
    
    // no add this to the selectEl to the object;
    this._selectEl = selectEl ;
    
    // now create an element for the applet 
    this.appletElement();
    
    // now add listeners to the selectEl;
    this._addListeners();
    
    // initializing options for JMOL;
    jmolSetDocument( 0 );
    jmolInitialize( this._jmolUrl ); // REQUIRED
    //jmolInitialize(" http://localhost:3000/static/jmol "); // REQUIRED
    //jmolInitialize(" http://localhost:8001/catalyst/ipfam/static/jmol "); // REQUIRED
    jmolSetAppletColor( 'cyan' );
    
    // create an JMOL applet & set the chain for ref;
    this.setShownStructure( this._selectEl.value );
    //this._shownStructure = this._selectEl.value;
    this.jmolViewer( );
    
    // show the element;
    this._parent.show();  
  },
  
  //----------------------------------------------------------------------------
  
  // function to create the jmol viewer in the page;
  jmolViewer: function( ){
    
    // change the shown strcture to be this one;
    var pdb = this.getShownStructure();
    console.log( 'new Strucutre to be shown '+ pdb );
    
    // now get the first 4 letters of the PDB id leaving the chain details;
    var list = /(\w{4})\.\w+/.exec( pdb );
     
    var pdb_id = list[1];
      
    var string = 'background white;load http://localhost:3000/structure/getpdb?id=' + pdb_id;
    string += ';select all;cartoon on;cpk off; wireframe off;';
    
    console.log( 'the string is '+ string );
    
    var myApplet = jmolApplet( 250, string, 'foo' );
    
    // now update the applet element with this value;
    this._appletEl.update( myApplet );
    
  },
  
  //----------------------------------------------------------------------------
  
  // function to create applet element;
  appletElement: function(){
    console.log( 'Creating an element for applet ' );
    
    var appletId = new Element( 'div', { 'id': 'appletId' } );
    
    this._appletEl = appletId;
    
    this._parent.appendChild( appletId );
    
    this._parent.appendChild( this._selectEl );
    
  }, 
  
  //------------------------------------------------------------------------------
  //- Getters and Setters --------------------------------------------------------
  //------------------------------------------------------------------------------
  
  // function to set parent;
  setParent: function( parent ){
    this._parent = $( parent );
    console.log('the parent is '+this._parent.inspect() );
    
    if ( this._parent === undefined || this._parent === null ) {
      this._throw( "couldn't find the node"+parent );
    }
      
  },
  
  //--------------------------------------
  
  // function to get the parent;
  getParent: function(){
    return this._parent;
  },
  
  //----------------------------------------------------------------------------
  
  // function to set the accession;
  setAccession: function( accession ){
    this._accession = accession;
    
    //check whether we get the accession as a string;
    if( this._accession === null ){
      this._throw( 'Accession cannot be null' );
    }
    
    // use regex to check we get any invalid characters in the string;
    if( /\W+/.test( this._accession ) ){
      this._throw( 'Accession contains invalid characters');
    }
    
    
  }, // end of setAccession
  
  //-------------------------------------
  
  // function to return the accession 
  getAccession: function(){
    return this._accession;
  },
  
  //----------------------------------------------------------------------------
  
  // function to set the readyState of this object;
  setReadyState: function( status ){
    this._readyState = status;  
  },
  
  //--------------------------------------
  
  getReadyState: function( ){
    return this._readyState;
  },
  
  //----------------------------------------------------------------------------
  
  // function to set the current shown structure;
  setShownStructure: function( pdb ){
    this._shownStructure = pdb;
  },
  
  //--------------------------------------
  
  // fucntion to get the shown structure;
  getShownStructure: function(){
    return this._shownStructure;
  },
  
  //--------------------------------------
  isStructureChanged: function(){
    return this._structureChanged;
  },
  
  // function to set the status change of the structure;
  setStructureChange: function( bool ){
    this._structureChanged = bool;
  },
  
  //------------------------------------------------------------------------------
  //- Private Methods ------------------------------------------------------------
  //------------------------------------------------------------------------------
  
  // function to add event listeners for the select El;
  _addListeners: function(){
    
    this._selectEl.observe( 'change', function( ){
      
      console.log( 'the selected option is '+ this._selectEl.value );
      
      this._structureChanged = true;
      
      this.setShownStructure( this._selectEl.value );
      
      // call the jmol viewer function with the pdb_id;
      this.jmolViewer( );
       
    }.bind( this ) );
  },
  
  //----------------------------------------------------------------------------
  
  
  _throw: function( msg ){
    throw {
      name: 'WidgetTaggerException',
      message:  msg,
      toString: function(){ return this.message }
    };
          
  }
  
} ); // end of Class.create;