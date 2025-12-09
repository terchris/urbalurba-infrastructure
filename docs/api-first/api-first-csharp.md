# API-First Development for C# Developers

## What is API-First?

Instead of writing code first, you **design your API contract first** in an OpenAPI specification. Then you generate code from that contract. This ensures everyone agrees on what the API should look like before any coding starts.

---

## Workflow Overview

### Phase 1: Design

• **Write OpenAPI spec** (`api-spec.yaml`)
  - *Note: This is your contract - think carefully about data models and endpoints*
  - *Tip: Use Swagger Editor online to validate as you write*

• **Validate specification**
  - `nswag validate /input:api-spec.yaml`
  - *Note: Fix all validation errors before proceeding*

### Phase 2: Generate Code

• **Generate server stubs**
  - `nswag openapi2cscontroller` → Creates controller templates
  - *Note: Generated code has `NotImplementedException()` - that's expected*

• **Generate client code**
  - `nswag openapi2csclient` → Creates typed HTTP client
  - *Note: Client automatically handles serialization/deserialization*

### Phase 3: Implement

• **Implement server logic**
  - Fill in the `NotImplementedException()` methods
  - *Note: Use partial classes to keep your code separate from generated code*

• **Test with generated client**
  - Use the generated client interfaces for testing
  - *Note: Perfect contract compliance guaranteed*

### Phase 4: Iterate

• **Update spec** → **Regenerate** → **Update implementation**
  - *Note: Breaking changes in spec = compile errors in code (this is good!)*
  - *Tip: Version your API specs (`v1.yaml`, `v2.yaml`) for major changes*

## Key Success Factors

🎯 **Start simple** - Few endpoints, basic models  
🎯 **Validate early** - Fix spec issues before generating code  
🎯 **Separate concerns** - Generated code vs. implementation code  
🎯 **Version control specs** - Treat them like source code  
🎯 **Share specs first** - Get agreement before implementation  

## Common Gotchas

⚠️ **Don't edit generated files** - They get overwritten  
⚠️ **Use `operationId`** - Controls method names in generated code  
⚠️ **Be specific with data types** - `integer` vs `number`, `date-time` formats  
⚠️ **Handle errors in spec** - Define 400, 404, 500 responses  

## Workflow Summary

```
YAML Spec → Validate → Generate → Implement → Test → Repeat
```

*The beauty: Your API contract becomes executable code that stays in sync!*

---

## Step-by-Step Tutorial

### Step 1: Install Tools

```bash
# Install NSwag globally
dotnet tool install -g NSwag.ConsoleCore

# Create your solution
dotnet new sln -n TodoApi
mkdir TodoApi.Specs
mkdir TodoApi.Server
mkdir TodoApi.Client
```

### Step 2: Create Your First API Specification

Create `TodoApi.Specs/todo-api.yaml`:

```yaml
openapi: 3.0.0
info:
  title: Todo API
  version: 1.0.0
  description: A simple Todo API for learning

servers:
  - url: https://localhost:7001
    description: Development server

paths:
  /todos:
    get:
      summary: Get all todos
      operationId: GetTodos
      tags:
        - Todos
      responses:
        '200':
          description: List of todos
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Todo'
    
    post:
      summary: Create a new todo
      operationId: CreateTodo
      tags:
        - Todos
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateTodoRequest'
      responses:
        '201':
          description: Todo created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Todo'

  /todos/{id}:
    get:
      summary: Get todo by ID
      operationId: GetTodo
      tags:
        - Todos
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Todo found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Todo'
        '404':
          description: Todo not found

components:
  schemas:
    Todo:
      type: object
      required:
        - id
        - title
        - completed
      properties:
        id:
          type: integer
          example: 1
        title:
          type: string
          example: "Buy groceries"
        completed:
          type: boolean
          example: false
        createdAt:
          type: string
          format: date-time

    CreateTodoRequest:
      type: object
      required:
        - title
      properties:
        title:
          type: string
          example: "Buy groceries"
```

### Step 3: Validate Your Specification

```bash
cd TodoApi.Specs
nswag validate /input:todo-api.yaml
```

✅ If you see "Document is valid" - you're good to go!

### Step 4: Generate Server Code

Create `TodoApi.Server/nswag-server.json`:

```json
{
  "runtime": "Net80",
  "documentGenerator": {
    "fromDocument": {
      "url": "../TodoApi.Specs/todo-api.yaml"
    }
  },
  "codeGenerators": {
    "openApiToCSharpController": {
      "className": "{controller}",
      "namespace": "TodoApi.Server.Controllers",
      "controllerBaseClass": "Microsoft.AspNetCore.Mvc.ControllerBase",
      "generateModelValidationAttributes": true,
      "routeNamingStrategy": "OperationId",
      "output": "Controllers/TodosController.cs"
    }
  }
}
```

Generate the server:

```bash
cd TodoApi.Server
dotnet new webapi --no-openapi
nswag run nswag-server.json
```

### Step 5: Implement Your Controller

The generated `Controllers/TodosController.cs` will look like this:

```csharp
// This is GENERATED - don't edit directly
[ApiController]
public partial class TodosController : ControllerBase
{
    [HttpGet]
    [Route("/todos")]
    public virtual async Task<ActionResult<ICollection<Todo>>> GetTodos()
    {
        throw new NotImplementedException();
    }

    [HttpPost]
    [Route("/todos")]
    public virtual async Task<ActionResult<Todo>> CreateTodo([FromBody] CreateTodoRequest body)
    {
        throw new NotImplementedException();
    }

    [HttpGet]
    [Route("/todos/{id}")]
    public virtual async Task<ActionResult<Todo>> GetTodo([FromRoute] int id)
    {
        throw new NotImplementedException();
    }
}
```

**Create your implementation** in `Controllers/TodosController.Implementation.cs`:

```csharp
using Microsoft.AspNetCore.Mvc;

namespace TodoApi.Server.Controllers;

// This is YOUR code - implement the actual logic
public partial class TodosController
{
    private static readonly List<Todo> _todos = new();
    private static int _nextId = 1;

    public override async Task<ActionResult<ICollection<Todo>>> GetTodos()
    {
        return Ok(_todos);
    }

    public override async Task<ActionResult<Todo>> CreateTodo([FromBody] CreateTodoRequest request)
    {
        var todo = new Todo
        {
            Id = _nextId++,
            Title = request.Title,
            Completed = false,
            CreatedAt = DateTime.UtcNow
        };
        
        _todos.Add(todo);
        return CreatedAtAction(nameof(GetTodo), new { id = todo.Id }, todo);
    }

    public override async Task<ActionResult<Todo>> GetTodo([FromRoute] int id)
    {
        var todo = _todos.FirstOrDefault(t => t.Id == id);
        if (todo == null)
            return NotFound();
            
        return Ok(todo);
    }
}
```

### Step 6: Generate Client Code

Create `TodoApi.Client/nswag-client.json`:

```json
{
  "runtime": "Net80",
  "documentGenerator": {
    "fromDocument": {
      "url": "../TodoApi.Specs/todo-api.yaml"
    }
  },
  "codeGenerators": {
    "openApiToCSharpClient": {
      "className": "TodoApiClient",
      "namespace": "TodoApi.Client",
      "generateClientInterfaces": true,
      "generateExceptionClasses": true,
      "output": "TodoApiClient.cs"
    }
  }
}
```

Generate the client:

```bash
cd TodoApi.Client
dotnet new classlib
dotnet add package Microsoft.Extensions.Http
nswag run nswag-client.json
```

### Step 7: Test Everything

**Start your server:**

```bash
cd TodoApi.Server
dotnet run
```

**Create a simple console app to test:**

```bash
dotnet new console -n TodoApi.TestApp
cd TodoApi.TestApp
dotnet add reference ../TodoApi.Client
dotnet add package Microsoft.Extensions.Http
dotnet add package Microsoft.Extensions.DependencyInjection
```

**Test code** in `Program.cs`:

```csharp
using Microsoft.Extensions.DependencyInjection;
using TodoApi.Client;

// Setup DI
var services = new ServiceCollection();
services.AddHttpClient<ITodoApiClient, TodoApiClient>(client =>
{
    client.BaseAddress = new Uri("https://localhost:7001");
});

var provider = services.BuildServiceProvider();
var apiClient = provider.GetRequiredService<ITodoApiClient>();

// Test the API
try
{
    // Create a todo
    var newTodo = await apiClient.CreateTodoAsync(new CreateTodoRequest 
    { 
        Title = "Learn API-First Development" 
    });
    Console.WriteLine($"Created: {newTodo.Title}");

    // Get all todos
    var todos = await apiClient.GetTodosAsync();
    Console.WriteLine($"Total todos: {todos.Count}");

    // Get specific todo
    var todo = await apiClient.GetTodoAsync(newTodo.Id);
    Console.WriteLine($"Retrieved: {todo.Title}");
}
catch (Exception ex)
{
    Console.WriteLine($"Error: {ex.Message}");
}
```

## Key Benefits You Just Experienced

✅ **Contract-First**: Everyone agrees on the API before coding  
✅ **Type Safety**: Generated code prevents runtime errors  
✅ **Consistency**: Client and server match perfectly  
✅ **Documentation**: Your spec IS your documentation  
✅ **Testing**: Easy to mock generated interfaces  

## Next Steps

• **Update your spec** → **Regenerate code** → **Implement new features**
• **Version your API** by creating `todo-api-v2.yaml`
• **Share your spec** with frontend developers
• **Add authentication** to your OpenAPI spec
• **Deploy** and share the spec URL with consumers

**The magic**: Change the spec file, regenerate, and both server and client are automatically updated! 🎉
