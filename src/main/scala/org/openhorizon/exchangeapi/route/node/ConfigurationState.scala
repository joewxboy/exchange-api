/** Services routes for all of the /orgs/{organization}/nodes api methods. */
package org.openhorizon.exchangeapi.route.node

import jakarta.ws.rs.{POST, Path}
import akka.actor.ActorSystem
import akka.event.LoggingAdapter
import akka.http.scaladsl.server.Directives._
import akka.http.scaladsl.server.Route
import org.openhorizon.exchangeapi.auth._
import de.heikoseeberger.akkahttpjackson._
import io.swagger.v3.oas.annotations.parameters.RequestBody
import io.swagger.v3.oas.annotations.enums.ParameterIn
import io.swagger.v3.oas.annotations.media.{Content, ExampleObject, Schema}
import io.swagger.v3.oas.annotations.tags.Tag
import io.swagger.v3.oas.annotations._

import scala.concurrent.ExecutionContext
import slick.jdbc.PostgresProfile.api._

import scala.util._
import org.openhorizon.exchangeapi.table.node.NodesTQ
import org.openhorizon.exchangeapi.table.resourcechange.{ResChangeCategory, ResChangeOperation, ResChangeResource, ResourceChange}
import org.openhorizon.exchangeapi.utility.{ApiRespType, ApiResponse, ExchMsg, ExchangePosgtresErrorHandling, HttpCode}

import scala.language.postfixOps


/** Implementation for all of the /orgs/{organization}/nodes routes */
@Path("/v1/orgs/{organization}/nodes/{node}/services_configstate")
@io.swagger.v3.oas.annotations.tags.Tag(name = "node")
trait ConfigurationState extends JacksonSupport with AuthenticationSupport {
  // Will pick up these values when it is mixed in with ExchangeApiApp
  def db: Database
  def system: ActorSystem
  def logger: LoggingAdapter
  implicit def executionContext: ExecutionContext
  
  
  // =========== POST /orgs/{organization}/nodes/{node}/services_configstate ===============================
  @POST
  @Operation(
    summary = "Changes config state of registered services",
    description = "Suspends (or resumes) 1 or more services on this edge node. Can be run by the node owner or the node.",
    parameters = Array(
      new Parameter(
        name = "organization",
        in = ParameterIn.PATH,
        description = "Organization id."
      ),
      new Parameter(
        name = "node",
        in = ParameterIn.PATH,
        description = "ID of the node to be updated."
      )
    ),
    requestBody = new RequestBody(
      content = Array(
        new Content(
          examples = Array(
            new ExampleObject(
              value = """{
  "org": "myorg",
  "url": "myserviceurl",
  "configState": "suspended",
  "version": "1.0.0"
}
"""
            )
          ),
          mediaType = "application/json",
          schema = new Schema(implementation = classOf[PostNodeConfigStateRequest])
        )
      ),
      required = true
    ),
    responses = Array(
      new responses.ApiResponse(
        responseCode = "201",
        description = "response body",
        content = Array(
          new Content(mediaType = "application/json", schema = new Schema(implementation = classOf[ApiResponse]))
        )
      ),
      new responses.ApiResponse(
        responseCode = "401",
        description = "invalid credentials"
      ),
      new responses.ApiResponse(
        responseCode = "403",
        description = "access denied"
      ),
      new responses.ApiResponse(
        responseCode = "404",
        description = "not found"
      )
    )
  )
  def postConfigurationState(node: String,
                             organization: String,
                             resource: String): Route =
    entity(as[PostNodeConfigStateRequest]) { reqBody =>
      validateWithMsg(reqBody.getAnyProblem) {
        complete({
          db.run(NodesTQ.getRegisteredServices(resource).result.asTry.flatMap({
            case Success(v) =>
              logger.debug("POST /orgs/" + organization + "/nodes/" + node + "/configstate result: " + v)
              if (v.nonEmpty) reqBody.getDbUpdate(v.head, resource).asTry // pass the update action to the next step
              else DBIO.failed(new Throwable("Invalid Input: node " + resource + " not found")).asTry // it seems this returns success even when the node is not found
            case Failure(t) => DBIO.failed(t).asTry // rethrow the error to the next step. Is this necessary, or will flatMap do that automatically?
          }).flatMap({
            case Success(v) =>
              // Add the resource to the resourcechanges table
              logger.debug("POST /orgs/" + organization + "/nodes/" + node + "/configstate write row result: " + v)
              ResourceChange(0L, organization, node, ResChangeCategory.NODE, public = false, ResChangeResource.NODESERVICES_CONFIGSTATE, ResChangeOperation.CREATED).insert.asTry
            case Failure(t) => DBIO.failed(t).asTry
          })).map({
            case Success(n) =>
              logger.debug("PUT /orgs/" + organization + "/nodes/" + node + " updating resource status table: " + n)
              if (n.asInstanceOf[Int] > 0) (HttpCode.PUT_OK, ApiResponse(ApiRespType.OK, ExchMsg.translate("node.services.updated", resource))) // there were no db errors, but determine if it actually found it or not
              else (HttpCode.NOT_FOUND, ApiResponse(ApiRespType.NOT_FOUND, ExchMsg.translate("node.not.found", resource)))
            case Failure(t: AuthException) => t.toComplete
            case Failure(t: org.postgresql.util.PSQLException) =>
              ExchangePosgtresErrorHandling.ioProblemError(t, ExchMsg.translate("node.not.inserted.or.updated", resource, t.getMessage))
            case Failure(t) =>
              (HttpCode.BAD_INPUT, ApiResponse(ApiRespType.BAD_INPUT, ExchMsg.translate("node.not.inserted.or.updated", resource, t.getMessage)))
          })
        })
      }
    }
  
  val configurationState: Route =
    path("orgs" / Segment / "nodes" / Segment / "services_configstate") {
      (organization,
       node) =>
        val resource: String = OrgAndId(organization, node).toString
        
        post {
          exchAuth(TNode(resource),Access.WRITE) {
            _ =>
              postConfigurationState(node, organization, resource)
          }
        }
    }
}
