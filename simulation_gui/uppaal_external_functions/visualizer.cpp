
#include <curlpp/Easy.hpp>
#include <curlpp/Options.hpp>
#include <curlpp/cURLpp.hpp>
#include <nlohmann/json.hpp>
#include <sstream>

extern "C" void send_state_via_post_request(int n_cols, int n_rows, int cells[],
                                            bool drones[]) {
  nlohmann::json state;

  state["N_COLS"] = n_cols;
  state["N_ROWS"] = n_rows;
  state["cells"] = nlohmann::json::array();
  state["drones"] = nlohmann::json::array();

  for (int x = 0; x < n_cols; x++) {
    state["cells"][x] = nlohmann::json::array();
    state["drones"][x] = nlohmann::json::array();
    for (int y = 0; y < n_rows; y++) {
      state["cells"][x][y] = cells[x * n_cols + y];
      state["drones"][x][y] = drones[x * n_cols + y];
    }
  }

  std::list<std::string> header;
  header.push_back("Content-Type: application/json");

  curlpp::Easy request;
  std::stringstream response;

  request.setOpt(new curlpp::options::HttpHeader(header));
  request.setOpt(curlpp::options::Url(std::string("127.0.0.1:5000/state")));
  request.setOpt(new curlpp::options::PostFields(state.dump()));
  request.setOpt(new curlpp::options::WriteStream(&response));

  try {
    request.perform();
  } catch (std::exception e) {
    // ...
  }
}
