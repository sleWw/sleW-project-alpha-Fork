using Godot;

namespace ProjectAlpha;

/// <summary>
/// Example C# script for Godot
/// This demonstrates basic C# usage in your project
/// </summary>
public partial class ExampleCSharp : Node
{
    public override void _Ready()
    {
        GD.Print("Hello from C#!");
        HelloWorld();
    }

    private void HelloWorld()
    {
        GD.Print("C# is ready to use!");
    }
}
