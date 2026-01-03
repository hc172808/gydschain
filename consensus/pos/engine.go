package pos

type Engine struct {
    Validators map[string]*Validator
}

func NewEngine() *Engine {
    return &Engine{
        Validators: make(map[string]*Validator),
    }
}
