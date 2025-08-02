using System;
using System.Collections.Generic;

namespace TestNamespace
{
    // This is a test class
    public class TestClass
    {
        // A simple property
        public string Name { get; set; }
        
        /* This is a multi-line
           comment that should be
           removed in standard mode */
        public void TestMethod()
        {
            // Single line comment
            Console.WriteLine("Hello World");
            
            var list = new List<string>();
            
            
            // More comments here
        }
    }
}