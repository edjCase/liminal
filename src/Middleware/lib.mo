import Pipeline "../Pipeline";
import Cors "./Cors";

module {
    public func useCors(data : Pipeline.PipelineData, options : Cors.Options) : Pipeline.PipelineData = Cors.useCors(data, options);
};
