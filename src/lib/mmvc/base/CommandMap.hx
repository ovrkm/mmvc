/*
Copyright (c) 2012 Massive Interactive

Permission is hereby granted, free of charge, to any person obtaining a copy of 
this software and associated documentation files (the "Software"), to deal in 
the Software without restriction, including without limitation the rights to 
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
of the Software, and to permit persons to whom the Software is furnished to do 
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
SOFTWARE.
*/

package mmvc.base;

import msignal.Signal;
import minject.Injector;
import mmvc.api.ICommand;
import mmvc.api.ICommandMap;
import mcore.data.Dictionary;

class CommandMap implements ICommandMap
{
	var injector:Injector;
	var signalMap:Dictionary<Dynamic, Dynamic>;
	var signalClassMap:Dictionary<Dynamic, Dynamic>;
	var detainedCommands:Dictionary<Dynamic, Dynamic>;

	public function new(injector:Injector)
	{
		this.injector = injector;

		signalMap = new Dictionary();
		signalClassMap = new Dictionary();
		detainedCommands = new Dictionary();
	}
	
	public function mapSignal(signal:AnySignal, commandClass:Class<ICommand>, ?oneShot:Bool=false)
	{
		if (hasSignalCommand(signal, commandClass)) return;

		var signalCommandMap:Dictionary<Dynamic, Dynamic>;
		if (signalMap.exists(signal))
		{
			signalCommandMap = signalMap.get(signal);
		}
		else
		{
			signalCommandMap = new Dictionary(false);
			signalMap.set(signal, signalCommandMap);
		}
		
		var me = this;
		var callbackFunction = Reflect.makeVarArgs(function(args)
		{
			me.routeSignalToCommand(signal, args, commandClass, oneShot);
		});

		signalCommandMap.set(commandClass, callbackFunction);
		signal.add(callbackFunction);
	}

	public function mapSignalClass(signalClass:SignalClass, commandClass:CommandClass, ?oneShot:Bool=false):AnySignal
	{
		var signal = getSignalClassInstance(signalClass);
		mapSignal(signal, commandClass, oneShot);
		return signal;
	}

	public function unmapSignalClass(signalClass:SignalClass, commandClass:CommandClass)
	{
		unmapSignal(getSignalClassInstance(signalClass), commandClass);
		injector.unmap(signalClass);
	}

	function getSignalClassInstance(signalClass:SignalClass):AnySignal
	{
		if (signalClassMap.exists(signalClass))
		{
			return cast(signalClassMap.get(signalClass), AnySignal);
		}

		var signal = createSignalClassInstance(signalClass);
		signalClassMap.set(signalClass, signal);
		return signal;
	}

	function createSignalClassInstance(signalClass:SignalClass):AnySignal
	{
		var injectorForSignalInstance = injector;
		var signal:AnySignal;
		
		if (injector.hasMapping(Injector))
		{
			injectorForSignalInstance = injector.getInstance(Injector);
		}
		
		signal = injectorForSignalInstance.instantiate(signalClass);
		injectorForSignalInstance.mapValue(signalClass, signal);
		signalClassMap.set(signalClass, signal);

		return signal;
	}

	public function hasSignalCommand(signal:AnySignal, commandClass:Class<ICommand>):Bool
	{
		var callbacksByCommandClass = signalMap.get(signal);
		if (callbacksByCommandClass == null) return false;
		
		var callbackFunction = callbacksByCommandClass.get(commandClass);
		return callbackFunction != null;
	}

	public function unmapSignal(signal:AnySignal, commandClass:CommandClass)
	{
		var callbacksByCommandClass = signalMap.get(signal);
		if (callbacksByCommandClass == null) return;

		var callbackFunction = callbacksByCommandClass.get(commandClass);
		if (callbackFunction == null) return;
		
		signal.remove(callbackFunction);
		callbacksByCommandClass.delete(commandClass);
	}
	
	function routeSignalToCommand(signal:AnySignal, valueObjects:Array<Dynamic>, commandClass:CommandClass, oneshot:Bool)
	{
		mapSignalValues(signal.valueClasses, valueObjects);
		var command = createCommandInstance(commandClass);
		unmapSignalValues(signal.valueClasses, valueObjects);
		command.execute();
		
		if (oneshot)
		{
			unmapSignal(signal, commandClass);
		}
	}

	function createCommandInstance(commandClass:CommandClass):ICommand
	{
		return injector.instantiate(commandClass);
	}

	function mapSignalValues(valueClasses:Array<Dynamic>, valueObjects:Array<Dynamic>):Void
	{
		for (i in 0...valueClasses.length)
		{
			injector.mapValue(valueClasses[i], valueObjects[i]);
		}
	}

	function unmapSignalValues(valueClasses:Array<Dynamic>, valueObjects:Array<Dynamic>)
	{
		for (i in 0...valueClasses.length)
		{
			injector.unmap(valueClasses[i]);
		}
	}

	public function detain(command:ICommand)
	{
		detainedCommands.set(command, true);
	}

	public function release(command:ICommand)
	{
		if (detainedCommands.exists(command))
		{
			detainedCommands.delete(command);
		}
	}
}
