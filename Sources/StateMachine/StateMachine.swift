import Foundation

// https://www.figure.ink/blog/2015/2/9/swift-state-machines-part-4-redirect
// https://gist.github.com/jemmons/f30f1de292751da0f1b7

public class StateMachine<P:StateMachineDelegateProtocol>{
  private unowned let delegate:P

  private var _state:P.StateType{
    didSet{
        delegate.didTransition(from: oldValue, to:_state)
    }
  }

  public var state:P.StateType{
    get{
      return _state
    }
    set{ //Can't be an observer because we need the option to CONDITIONALLY set state
        delegateTransition(to: newValue)
    }
  }


  public init(initialState:P.StateType, delegate:P){
    _state = initialState //set the primitive to avoid calling the delegate.
    self.delegate = delegate
  }


  private func delegateTransition(to:P.StateType){
    switch delegate.shouldTransition(from: _state, to:to){
    case .Continue:
      _state = to
    case .Redirect(let newState):
      _state = to
      state = newState
    case .Abort:
      break;
    }
  }
}

public protocol StateMachineDelegateProtocol: class{
    associatedtype StateType
  func shouldTransition(from:StateType, to:StateType)->Should<StateType>
  func didTransition(from:StateType, to:StateType)
}

public enum Should<T>{
  case Continue, Abort, Redirect(T)
}
