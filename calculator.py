def add(a, b):
    return a + b

def subtract(a, b):
    return a - b

def multiply(a, b):
    return a * b

def divide(a, b):
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b

def calculator():
    print("Simple Calculator")
    print("Operations: +, -, *, /")
    print("Type 'quit' to exit\n")

    while True:
        try:
            user_input = input("Enter expression (e.g. 5 + 3): ").strip()
            if user_input.lower() == "quit":
                print("Goodbye!")
                break

            for op in ("+", "-", "*", "/"):
                if op in user_input:
                    parts = user_input.split(op)
                    if len(parts) == 2:
                        a = float(parts[0].strip())
                        b = float(parts[1].strip())
                        ops = {
                            "+": add,
                            "-": subtract,
                            "*": multiply,
                            "/": divide,
                        }
                        result = ops[op](a, b)
                        print(f"Result: {result}\n")
                        break
            else:
                print("Invalid expression. Use format: number operator number\n")

        except ValueError as e:
            print(f"Error: {e}\n")
        except Exception:
            print("Invalid input. Please try again.\n")

if __name__ == "__main__":
    calculator()
