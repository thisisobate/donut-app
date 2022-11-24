import "./App.css";
import strawberryDonut from "./assets/Happy-pride-donut.png";
import cakeDonut from "./assets/Nomads - Donuts.png";
import healthyDonut from "./assets/Wormies - Donut.png";

function App() {
  return (
    <>
      <main className="app">
        <section>
          <p>Types of Donut:</p>
          <div className="grid">
            <div className="item">
              <div className="img-holder">
                <img src={strawberryDonut} alt="happy pride donut" />
              </div>
              <div>
                <p>Name: Strawberry Donut </p>
              </div>
            </div>
            <div className="item">
              <div className="img-holder">
                <img src={cakeDonut} alt="cake donut" />
              </div>
              <div>
                <p>Name: Cake Donut </p>
              </div>
            </div>
            <div className="item">
              <div className="img-holder">
                <img src={healthyDonut} alt="healthy donut" />
              </div>
              <div>
                <p>Name: Healthy Donut </p>
              </div>
            </div>
          </div>
          {/* <button>view more</button> */}
        </section>
        {/* <section className="callToAction">
          <p>Want to support the next gen of leaders with books?</p>
          <button>Donate</button>
        </section>
      */}
      </main>
      <footer>
        <div className="container">
          <div></div>
          <div></div>
        </div>
        <div>Made with &#10084;&#65039; by Obate</div>
      </footer>
    </>
  );
}
export default App;
