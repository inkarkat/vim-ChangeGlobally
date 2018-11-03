public interface IOperatorActionPM
{
  [Bindable(event="eventPropertyChanged")]
  function get hasCommand():Boolean;

  [Bindable(event="eventPropertyChanged")]
  function get command():String;

  function set command(value:String):void;

  [Bindable(event="eventPropertyChanged")]
  function get node():String;

  function set node(value:String):void;

  [Bindable(event="eventPropertyChanged")]
  function get nodeList():ArrayCollection;

  [Bindable(event="eventPropertyChanged")]
  function get appendNodeList():Boolean;

  function set appendNodeList(value:Boolean):void;

  [Bindable(event="eventPropertyChanged")]
  function get autoAckMsg():Boolean;

  function set autoAckMsg(value:Boolean):void;
}
