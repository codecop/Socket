Event do(
	//doc Event category Networking
	descriptorId ::= -1
	eventType ::= nil
	timeout ::= 10
	coro ::= nil // internal
	EV_TIMER ::= 0
	//debugWriteln := getSlot("writeln")
	
	eventTypeName := method(
		if(eventType == EV_READ,   return "EV_READ")
		if(eventType == EV_WRITE,  return "EV_WRITE")
		if(eventType == EV_SIGNAL, return "EV_SIGNAL")
		if(eventType == EV_TIMER,  return "EV_TIMER")
		"?"
	)

	/*doc Event handleEvent(timeout) 
	
	*/
	handleEvent := method(isTimeout,
		//writeln("Event ", eventTypeName, " handleEvent(", isTimeout, ")")
		//debugWriteln(coro label, " resuming - got ", eventTypeName)
		self isTimeout := isTimeout
		if(coro,
			tmpCoro := coro
			//debugWriteln("Event handleEvent - resuming ", coro label)
			setCoro(nil)
			tmpCoro resumeLater
			//yield
		)
	)

	//doc Event waitOnOrExcept(timeout) 
	waitOn := method(t,
		if(t, timeout = t)

		if(coro, return(Error with("Already waiting on this event")))
		coro = Scheduler currentCoroutine
		//writeln(coro label, " ", eventTypeName, " waitOn(", t, ") - pausing")
		EventManager addEvent(self, descriptorId, eventType, timeout) ifError(e, coro = nil; return(e))
		coro pause
		debugWriteln(Scheduler currentCoroutine label, " Event waitOn(", t, ") - resumed")
		if(isTimeout, Error with("Timeout"), self)
	)

	//doc Event waitOnOrExcept(timeout) Same as waitOn() but an exception is raised if a timeout occurs. Returns self.
	waitOnOrExcept := method(t,
		waitOn(t)
		isTimeout ifTrue(Exception raise("timeout"))
		self
	)
	
	timeoutNow := method(
		EventManager resetEventTimeout(self, 0)
		self
	)
	
	resetTimeout := method(
		EventManager resetEventTimeout(self, timeout)
		self
	)
)

ReadEvent := Event clone setEventType(Event EV_READ) do(
	//metadoc ReadEvent category Networking
	//metadoc ReadEvent description Object for read events.
	nil
)

WriteEvent  := Event clone setEventType(Event EV_WRITE) do(
	//metadoc WriteEvent category Networking
	//metadoc WriteEvent description Object for write events.
	nil
)

SignalEvent := Event clone setEventType(Event EV_SIGNAL) do(
	//metadoc SignalEvent category Networking
	//metadoc SignalEvent description Object for signal events.
	nil
)

TimerEvent  := Event clone setEventType(Event EV_TIMER) do(
	//metadoc TimerEvent category Networking
	//metadoc TimerEvent description Object for timer events.
	nil
)

Object wait := method(t, TimerEvent clone setTimeout(t) waitOn)

EventManager do(
	//metadoc EventManager category Networking
	/*metadoc EventManager description 
	Object for libevent (kqueue/epoll/poll/select) library. 
	Usefull for getting notifications for descriptor (a socket or file) events.
	Events include read (the descriptor has unread data or timeout) and write (the descriptor wrote some data or timeout).
	Also, timer and signal events are supported.
	*/
	isRunning ::= false
	coro ::= nil
	listensUntilEvent ::= true
	
	realAddEvent := getSlot("addEvent")
	shouldRun ::= true

	//doc EventManager addEvent(event, descriptor, eventType, timeout) 
	addEvent := method(e, descriptorId, eventType, timeout,
		//writeln("addEvent")
		//Exception raise("EventManager addEvent " .. e eventTypeName .. " - begin")
		//writeln("addEvent2")
		r := self realAddEvent(e, descriptorId, eventType, timeout)
		r returnIfError
		resumeIfNeeded
		//debugWriteln("EventManager addEvent " .. e eventTypeName .. " - done")
		r
	)
	
	resumeIfNeeded := method(
		if(coro, coro resumeLater, self coro := coroFor(run); coro setLabel("EventManager"); coro resumeLater)	
	)

	//doc EventManager run Runs the EventManger loop. Does not return. Private - should only be called by resumeIfNeeded.
	run := method(
		//writeln("EventManager run")
		//Scheduler currentCoroutine setLabel("EventManager")
		//writeln("EventManager run")
		setShouldRun(true)
		while(shouldRun,
			setIsRunning(true)
			//while(hasActiveEvents and shouldRun,
			loop(
				/*
				if(Coroutine yieldingCoros size > 0,
					writeln("Coroutine yieldingCoros size = ", Coroutine yieldingCoros size)
					writeln("label: ", Coroutine yieldingCoros first label)
				)
				*/
				//writeln("EventManager listening")
				er := if(Coroutine yieldingCoros first, listen, if(listensUntilEvent, listenUntilEvent, listen)) 
				er ifError(e, Exception raise("Unrecoverable Error in EventManager: " .. e description))

				yield
			)
			setIsRunning(false)
			coro pause
		)
	)
	
	stop := method(
		setShouldRun(false)
	)
)

Scheduler currentCoroutine setLabel("main")
EventManager setListenTimeout(1)

if(getSlot("EvConnection"),
	EvConnection do(
		eventManager ::= EventManager
		address ::= ""
		port ::= 80
		newRequest := method(EvOutRequest clone setConnection(self))
		didFinish := nil
	)

	EvOutRequest do(
		requestHeaders := Map clone
		requestHeaders atPut("User-Agent", "Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/312.8 (KHTML, like Gecko) Safari/312.6)")
		requestHeaders atPut("Connection", "close")
		requestHeaders atPut("Accept", "*/*")
	
		init := method(
			self requestHeaders := requestHeaders clone	
		)

		connection ::= nil
		requestType ::= "GET"
		uri ::= "/index.html"

		send := method(
			self requestHeaders atPut("Host", connection address, connection port)
			writeln("EvOutRequest send ", self uniqueId, " ", uri)
			self waitingCoro := Coroutine currentCoroutine
			asyncSend
			EventManager resumeIfNeeded
			yield
			waitingCoro pause
		)

		didFinish := method(
			writeln("EvOutRequest recv ", self uniqueId, " ", uri)
			waitingCoro resumeLater
		)
	)
)

